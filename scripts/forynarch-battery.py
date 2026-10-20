#!/usr/bin/env python3
"""Read battery telemetry without starting a service or changing power settings."""
import json
import math
from pathlib import Path


def value(node, field):
    try:
        return (node / field).read_text().strip()
    except (OSError, UnicodeError):
        return None


def number(node, field):
    try:
        result = float(value(node, field))
        return result if math.isfinite(result) else None
    except (TypeError, ValueError):
        return None


def positive(node, field):
    result = number(node, field)
    return result if result is not None and result >= 0 else None


def power(node):
    watts = number(node, "power_now")
    if watts is not None:
        return abs(watts) / 1_000_000, "power_now"
    current, voltage = number(node, "current_now"), positive(node, "voltage_now")
    if current is not None and voltage is not None:
        return abs(current) * voltage / 1_000_000_000_000, "current_now * voltage_now"
    return None, None


def battery(node):
    watts, source = power(node)
    status = value(node, "status") or "Unknown"
    capacity = positive(node, "capacity")
    if capacity is not None and capacity > 100:
        capacity = None
    energy = positive(node, "energy_now")
    full = positive(node, "energy_full")
    design = positive(node, "energy_full_design")
    charge = positive(node, "charge_now")
    charge_full = positive(node, "charge_full")
    charge_design = positive(node, "charge_full_design")
    if capacity is None:
        now, maximum = (energy, full) if energy is not None and full else (charge, charge_full)
        if now is not None and maximum:
            capacity = min(100, now / maximum * 100)
    health = None
    if full is not None and design:
        health = full / design * 100
    elif charge_full is not None and charge_design:
        health = charge_full / charge_design * 100
    seconds, estimated = None, False
    if status in ("Charging", "Discharging"):
        field = "time_to_full_now" if status == "Charging" else "time_to_empty_now"
        seconds = positive(node, field)
        if not seconds:
            seconds = None
            remaining = None
            if energy is not None and (status == "Discharging" or full is not None):
                remaining = energy if status == "Discharging" else max(0, full - energy)
                if watts and remaining:
                    seconds = remaining / 1_000_000 / watts * 3600
            elif charge is not None and (status == "Discharging" or charge_full is not None):
                remaining = charge if status == "Discharging" else max(0, charge_full - charge)
                current = number(node, "current_now")
                if current and remaining:
                    seconds = remaining / abs(current) * 3600
            estimated = seconds is not None
    temp = number(node, "temp")
    return {"name": node.name, "status": status, "capacity": capacity,
            "watts": watts, "powerSource": source, "health": health,
            "energyWh": energy / 1_000_000 if energy is not None else None,
            "fullWh": full / 1_000_000 if full is not None else None,
            "seconds": seconds, "timeEstimated": estimated,
            "temperatureC": temp / 10 if temp is not None else None,
            "cycles": positive(node, "cycle_count")}


def collect(root=Path("/sys/class/power_supply")):
    batteries, adapters = [], []
    try:
        nodes = sorted(root.iterdir())
    except OSError:
        nodes = []
    for node in nodes:
        kind = value(node, "type")
        if kind == "Battery":
            if value(node, "present") != "0" and value(node, "scope") != "Device":
                batteries.append(battery(node))
        elif kind and value(node, "online") in ("0", "1"):
            online = value(node, "online") == "1"
            watts, _ = power(node) if online else (None, None)
            adapters.append({"name": node.name, "type": kind, "online": online, "watts": watts})
    capacities = [row["capacity"] for row in batteries if row["capacity"] is not None]
    if batteries and all(row["energyWh"] is not None and row["fullWh"] for row in batteries):
        capacity = min(100, sum(row["energyWh"] for row in batteries) /
                       sum(row["fullWh"] for row in batteries) * 100)
    else:
        capacity = sum(capacities) / len(capacities) if capacities else None
    return {"batteries": batteries, "adapters": adapters, "capacity": capacity,
            "externalPower": any(row["online"] for row in adapters),
            "charging": any(row["status"] == "Charging" for row in batteries)}


if __name__ == "__main__":
    print(json.dumps(collect(), allow_nan=False))
