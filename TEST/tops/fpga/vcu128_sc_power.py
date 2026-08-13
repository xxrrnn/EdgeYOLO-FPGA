#!/usr/bin/env python3
"""Read VCU128 rail power via the System Controller UART (not BoardUI.exe).

BoardUI.exe is a PyInstaller GUI.  This talks the same UART protocol it uses
on FTDI port D (config.yaml: ``system controller port: (?i){ser}D``):

  * every SC command is terminated with CR+TAB (``\\r\\t``)
  * handshake: ESC+BS+CR+TAB, then ESC+CR+TAB + ``~~~`` ping
  * I2C: ``IW0`` / ``IR0`` through mux 0x75 port 0x04 to the INA226s
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from dataclasses import asdict, dataclass

import serial
from serial.tools import list_ports

MUX_ADDR = 0x75
MUX_PMBUS = 0x04
MUX_OFF = 0x00

# (name, i2c addr, max_current_A, Rshunt_ohm) from SC.yaml Power tab.
RAILS = [
    ("VCCINT", 0x40, 125.0, 0.001),
    ("VCCBRAM", 0x41, 300.0, 0.001),
    ("VCC1V8", 0x42, 10.0, 0.005),
    ("MGTAVCC", 0x46, 10.0, 0.005),
    ("MGTVCCAUX", 0x48, 1.0, 0.005),
    ("VCCHBRM", 0x4C, 25.0, 0.001),
    ("VCCAUX_HBM", 0x4D, 1.0, 0.005),
    ("MGTAVTT", 0x47, 20.0, 0.001),
]

COMPUTE_RAILS = ("VCCINT", "VCCBRAM")


@dataclass
class RailSample:
    name: str
    volts: float
    amps: float
    watts: float
    bus_reg: int
    current_reg: int


def find_sc_port(explicit: str | None = None) -> str:
    if explicit:
        return explicit
    for info in list_ports.comports():
        serial_no = str(info.serial_number or "")
        hwid = info.hwid or ""
        if serial_no.upper().endswith("D") and ("0403" in hwid or "FTDI" in hwid):
            return info.device
    raise SystemExit(
        "System Controller COM port not found (expected FTDI serial ...D). "
        "Pass --port COMx. Close BoardUI.exe if it has the port open."
    )


def ina_cal(max_a: float, rshunt: float) -> int:
    current_lsb = max_a / 32768.0
    return max(1, int(round(0.00512 / (current_lsb * rshunt))))


def _s16(reg: int) -> int:
    return reg - 0x10000 if reg & 0x8000 else reg


class SysController:
    def __init__(self, port: str, baud: int = 115200, timeout: float = 1.0):
        self.ser = serial.Serial()
        self.ser.port = port
        self.ser.baudrate = baud
        self.ser.timeout = 0.05
        self.ser.stopbits = serial.STOPBITS_ONE
        self.ser.open()
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()
        self.cmd_timeout = timeout
        self._mux_on = False
        self.handshake()

    def close(self) -> None:
        try:
            if self._mux_on:
                self.disable_pmbus()
        except Exception:
            pass
        self.ser.close()

    def __enter__(self) -> "SysController":
        return self

    def __exit__(self, *exc) -> None:
        self.close()

    def _read_until(self, needles: tuple[str, ...], deadline: float) -> str:
        buf = bytearray()
        while time.time() < deadline:
            n = self.ser.in_waiting
            chunk = self.ser.read(n or 1)
            if chunk:
                buf.extend(chunk)
                text = buf.decode("latin1", errors="replace")
                if any(s in text for s in needles):
                    time.sleep(0.02)
                    extra = self.ser.read(self.ser.in_waiting or 0)
                    if extra:
                        buf.extend(extra)
                    return buf.decode("latin1", errors="replace")
            else:
                time.sleep(0.005)
        return buf.decode("latin1", errors="replace")

    def cmd(self, payload: str, wait_for: tuple[str, ...] = (":P\r", ":R\r", ":N\r"),
            timeout: float | None = None) -> str:
        if not payload.endswith("\t"):
            if not payload.endswith("\r"):
                payload += "\r"
            payload += "\t"
        self.ser.write(payload.encode("ascii"))
        self.ser.flush()
        return self._read_until(wait_for, time.time() + (timeout or self.cmd_timeout))

    def handshake(self) -> None:
        self.ser.reset_input_buffer()
        self.cmd("\x1b\x08\r\t", wait_for=("R\r", ":R\r"), timeout=1.0)
        ping = self.cmd("\x1b\r\t~~~\r\t", wait_for=("~~~\r:P\r", ":P\r"), timeout=1.5)
        if ":P" not in ping:
            ping = self.cmd("~~~\r\t", wait_for=("~~~\r:P\r", ":P\r"), timeout=1.5)
        if ":P" not in ping:
            raise RuntimeError(
                "SC UART did not ACK ping (~~~). Close BoardUI.exe and retry. "
                f"got={ping!r}"
            )

    def ping(self) -> None:
        raw = self.cmd("~~~\r\t", wait_for=("~~~\r:P\r", ":P\r"))
        if ":P" not in raw:
            raise RuntimeError(f"SC ping failed: {raw!r}")

    def i2c_write(self, addr: int, data_hex: str) -> str:
        return self.cmd(f"IW0\r{addr:02X}\r{data_hex}\r\t")

    def i2c_read(self, addr: int, nbytes: int = 2) -> int:
        raw = self.cmd(f"IR0\r{addr:02X}\r{nbytes}\r\t")
        hexes = re.findall(r"\b([0-9A-Fa-f]{4})\b", raw)
        if not hexes:
            raise RuntimeError(f"I2C read failed from 0x{addr:02X}: {raw!r}")
        return int(hexes[-1], 16)

    def enable_pmbus(self) -> None:
        self.i2c_write(MUX_ADDR, f"{MUX_PMBUS:02X}")
        self._mux_on = True
        time.sleep(0.03)

    def disable_pmbus(self) -> None:
        self.i2c_write(MUX_ADDR, f"{MUX_OFF:02X}")
        self._mux_on = False

    def cal_rail(self, addr: int, max_a: float, rshunt: float) -> None:
        cal = ina_cal(max_a, rshunt)
        self.i2c_write(addr, f"05{cal:04X}")
        time.sleep(0.02)

    def read_vi(self, addr: int, max_a: float) -> tuple[int, int, float, float, float]:
        current_lsb = max_a / 32768.0
        self.i2c_write(addr, "02")
        bus_reg = self.i2c_read(addr)
        self.i2c_write(addr, "04")
        current_reg = self.i2c_read(addr)
        volts = bus_reg * 0.00125
        amps = _s16(current_reg) * current_lsb
        return bus_reg, current_reg, volts, amps, volts * amps

    def read_rail(self, name: str, addr: int, max_a: float, rshunt: float,
                  calibrate: bool = True) -> RailSample:
        if calibrate:
            self.cal_rail(addr, max_a, rshunt)
        bus_reg, current_reg, volts, amps, watts = self.read_vi(addr, max_a)
        return RailSample(name, volts, amps, watts, bus_reg, current_reg)


def rail_by_name(name: str) -> tuple[str, int, float, float]:
    for spec in RAILS:
        if spec[0] == name:
            return spec
    raise KeyError(name)


def sample_rails(sc: SysController, names: tuple[str, ...] | None = None,
                 calibrate: bool = True) -> dict[str, RailSample]:
    wanted = names or tuple(spec[0] for spec in RAILS)
    if not sc._mux_on:
        sc.enable_pmbus()
    out: dict[str, RailSample] = {}
    for name in wanted:
        _, addr, max_a, rshunt = rail_by_name(name)
        out[name] = sc.read_rail(name, addr, max_a, rshunt, calibrate=calibrate)
    return out


def snapshot_dict(samples: dict[str, RailSample], t: float | None = None) -> dict:
    vccint = samples["VCCINT"].watts if "VCCINT" in samples else None
    bram = samples["VCCBRAM"].watts if "VCCBRAM" in samples else None
    compute = sum(samples[n].watts for n in COMPUTE_RAILS if n in samples)
    snap = {
        "t": t if t is not None else time.time(),
        "rails": {k: asdict(v) for k, v in samples.items()},
        "sum_watts": sum(v.watts for v in samples.values()),
        "vccint_watts": vccint,
        "vccbram_watts": bram,
        "compute_watts": compute,
    }
    return snap


def mean_watts(snaps: list[dict], key: str) -> float | None:
    vals = [s[key] for s in snaps if s.get(key) is not None]
    if not vals:
        return None
    return sum(vals) / len(vals)


def format_snapshot(samples: dict[str, RailSample]) -> str:
    lines = []
    for name, s in samples.items():
        lines.append(f"  {name:12s}  {s.volts:6.3f} V  {s.amps:7.3f} A  {s.watts:7.3f} W")
    total = sum(v.watts for v in samples.values())
    lines.append(f"  {'SUM':12s}  {'':6s}     {'':7s}    {total:7.3f} W")
    compute = sum(samples[n].watts for n in COMPUTE_RAILS if n in samples)
    if any(n in samples for n in COMPUTE_RAILS):
        lines.append(f"  {'VCCINT+BRAM':12s}  {'':6s}     {'':7s}    {compute:7.3f} W")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description="Read VCU128 INA226 rails via SC UART")
    ap.add_argument("--port", default=None)
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--json-out", default=None)
    ap.add_argument("--repeat", type=int, default=1, help="number of snapshots")
    ap.add_argument("--interval", type=float, default=0.5)
    ap.add_argument(
        "--rails",
        default="all",
        help="comma-separated rail names, or 'all' / 'compute' (VCCINT,VCCBRAM)",
    )
    args = ap.parse_args()
    if args.rails == "all":
        names = tuple(spec[0] for spec in RAILS)
    elif args.rails == "compute":
        names = COMPUTE_RAILS
    else:
        names = tuple(x.strip() for x in args.rails.split(",") if x.strip())

    port = find_sc_port(args.port)
    print(f"[power] SC UART {port} @ {args.baud}")
    snaps = []
    with SysController(port, args.baud) as sc:
        sc.enable_pmbus()
        for i in range(args.repeat):
            samples = sample_rails(sc, names, calibrate=(i == 0))
            snap = snapshot_dict(samples)
            snaps.append(snap)
            print(f"[power] snapshot {i + 1}/{args.repeat}")
            print(format_snapshot(samples))
            if i + 1 < args.repeat:
                time.sleep(args.interval)
        sc.disable_pmbus()

    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as f:
            json.dump(snaps if len(snaps) > 1 else snaps[0], f, indent=2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
