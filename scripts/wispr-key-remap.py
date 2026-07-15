#!/usr/bin/env python3
"""Device-level keyboard remap for Wispr Flow on Hyprland.

Why: Wispr's Linux helper reads raw EV_KEY codes from /dev/input, so Hyprland
XKB never reaches it. We grab physical keyboards and emit remapped events on
a full virtual keyboard:

  KEY_ESC      -> KEY_F20   (Wispr PTT)
  KEY_CAPSLOCK -> KEY_ESC   (cancel / normal Escape)

Never touches pointer-only devices. Never moves the cursor.
"""
from __future__ import annotations

import os
import select
import signal
import sys
import time
from pathlib import Path

import libevdev
from libevdev import EV_KEY, EV_MSC, EV_SYN, InputEvent

UINPUT_NAME = "wispr-key-remap"
SKIP_NAME_SUBSTR = (
    "wispr-key-remap",
    "ydotoold",
    "ydotool",
    "vicinae",
    "wispr flow linux helper",
    "wispr-flow-linux-helper",
    "test-kb-",
    "test-copy",
    "test-full",
)

LOG_PATH = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "wispr-key-remap.log"

REMAP = {
    EV_KEY.KEY_ESC: EV_KEY.KEY_F20,
    EV_KEY.KEY_CAPSLOCK: EV_KEY.KEY_ESC,
}


def log(msg: str) -> None:
    line = f"[{time.strftime('%F %T')}] {msg}"
    try:
        with LOG_PATH.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass
    print(line, flush=True)


def is_keyboard(dev: libevdev.Device) -> bool:
    if not (dev.has(EV_KEY.KEY_ESC) and dev.has(EV_KEY.KEY_A) and dev.has(EV_KEY.KEY_Z)):
        return False
    name = (dev.name or "").lower()
    for s in SKIP_NAME_SUBSTR:
        if s in name:
            return False
    if "virtual" in name and dev.has(libevdev.EV_REL.REL_X):
        return False
    return True


class Remapper:
    def __init__(self) -> None:
        self.stop = False
        self.sources: dict[str, tuple] = {}
        self.ui = None
        self.poll = select.poll()

    def request_stop(self, *_args) -> None:
        self.stop = True

    def ensure_uinput(self) -> None:
        if self.ui is not None:
            return
        d = libevdev.Device()
        d.name = UINPUT_NAME
        d.id = {
            "bustype": 0x03,
            "vendor": 0x5653,
            "product": 0x4B52,
            "version": 1,
        }
        # Enable a complete EV_KEY set so Wispr helper treats this as a real keyboard.
        # libevdev requires EventCode objects (evbit), not bare (type, int) tuples.
        enabled = 0
        for code in range(1, 768):
            try:
                bit = libevdev.evbit(1, code)  # 1 = EV_KEY
                if bit is None:
                    continue
                d.enable(bit)
                enabled += 1
            except Exception:
                pass
        # Repeat/autorepeat support
        try:
            d.enable(libevdev.EV_REP.REP_DELAY)
            d.enable(libevdev.EV_REP.REP_PERIOD)
        except Exception:
            pass
        self.ui = d.create_uinput_device()
        log(f"uinput created {self.ui.devnode} keys_enabled={enabled}")

    def open_device(self, path: str) -> None:
        if path in self.sources:
            return
        try:
            fd = open(path, "rb")
            os.set_blocking(fd.fileno(), False)
            dev = libevdev.Device(fd)
        except Exception as e:
            log(f"open fail {path}: {e}")
            return
        if not is_keyboard(dev):
            fd.close()
            return
        try:
            self.ensure_uinput()
            dev.grab()
        except Exception as e:
            log(f"grab fail {path} ({dev.name}): {e}")
            fd.close()
            return
        self.sources[path] = (fd, dev)
        self.poll.register(fd.fileno(), select.POLLIN | select.POLLERR | select.POLLHUP)
        log(f"grabbed {path} name={dev.name!r}")

    def close_device(self, path: str) -> None:
        tup = self.sources.pop(path, None)
        if not tup:
            return
        fd, _dev = tup
        try:
            self.poll.unregister(fd.fileno())
        except Exception:
            pass
        try:
            fd.close()
        except Exception:
            pass
        log(f"closed {path}")

    def scan(self) -> None:
        for p in sorted(Path("/dev/input").glob("event*")):
            self.open_device(str(p))
        for path in list(self.sources):
            if not Path(path).exists():
                self.close_device(path)

    def handle_events(self, path: str, dev: libevdev.Device) -> None:
        try:
            for ev in dev.events():
                if ev.type == EV_KEY:
                    mapped = REMAP.get(ev.code)
                    if mapped is not None:
                        self.ui.send_events([InputEvent(mapped, ev.value)])
                    else:
                        self.ui.send_events([ev])
                elif ev.type == EV_MSC:
                    continue
                elif ev.type == EV_SYN:
                    self.ui.send_events([ev])
                else:
                    try:
                        self.ui.send_events([ev])
                    except Exception:
                        pass
        except libevdev.EventsDroppedException:
            log(f"events dropped on {path}; syncing")
            try:
                for _ev in dev.sync():
                    pass
            except Exception:
                self.close_device(path)
        except OSError as e:
            log(f"read error {path}: {e}")
            self.close_device(path)

    def run(self) -> int:
        signal.signal(signal.SIGTERM, self.request_stop)
        signal.signal(signal.SIGINT, self.request_stop)
        log("start remap ESC->F20, CAPS->ESC")
        last_scan = 0.0
        while not self.stop:
            now = time.time()
            if now - last_scan > 2.0 or not self.sources:
                self.scan()
                last_scan = now
            if not self.sources:
                time.sleep(0.5)
                continue
            fdmap = {fd.fileno(): (path, dev) for path, (fd, dev) in self.sources.items()}
            try:
                ready = self.poll.poll(500)
            except InterruptedError:
                continue
            for fileno, flags in ready:
                if fileno not in fdmap:
                    continue
                path, dev = fdmap[fileno]
                if flags & (select.POLLERR | select.POLLHUP):
                    self.close_device(path)
                    continue
                self.handle_events(path, dev)
        for path in list(self.sources):
            self.close_device(path)
        log("stopped")
        return 0


if __name__ == "__main__":
    sys.exit(Remapper().run())
