import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("battery", Path(__file__).resolve().parents[1] / "scripts/forynarch-battery.py")
battery = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(battery)


class BatteryTelemetry(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def supply(self, name="BAT0", **fields):
        node = self.root / name
        node.mkdir()
        for field, value in fields.items():
            (node / field).write_text(str(value))
        return node

    def row(self):
        return battery.collect(self.root)["batteries"][0]

    def test_discharge_units_energy_and_remaining_estimate(self):
        self.supply(type="Battery", capacity=50, status="Discharging", power_now=12_000_000,
                    energy_now=24_000_000, energy_full=48_000_000, energy_full_design=60_000_000, temp=325)
        row = self.row()
        self.assertEqual((row["watts"], row["energyWh"], row["fullWh"], row["health"], row["temperatureC"]),
                         (12, 24, 48, 80, 32.5))
        self.assertEqual(row["seconds"], 7200)
        self.assertTrue(row["timeEstimated"])

    def test_signed_current_and_microvolt_conversion(self):
        self.supply(type="Battery", status="Charging", current_now=-2_000_000, voltage_now=12_000_000,
                    charge_now=2_000_000, charge_full=4_000_000, charge_full_design=5_000_000)
        row = self.row()
        self.assertEqual((row["watts"], row["capacity"], row["health"], row["seconds"]), (24, 50, 80, 3600))
        self.assertIsNone(row["energyWh"])

    def test_hardware_time_wins_over_estimate(self):
        self.supply(type="Battery", status="Charging", power_now=10_000_000,
                    energy_now=10_000_000, energy_full=50_000_000, time_to_full_now=3000)
        self.assertEqual(self.row()["seconds"], 3000)
        self.assertFalse(self.row()["timeEstimated"])

    def test_missing_values_do_not_fabricate_zero_watts(self):
        self.supply(type="Battery", capacity=0, status="Not charging")
        row = self.row()
        self.assertEqual(row["capacity"], 0)
        for field in ("watts", "seconds", "health", "energyWh", "cycles"):
            self.assertIsNone(row[field], field)

    def test_real_zero_watts_is_preserved(self):
        self.supply(type="Battery", status="Full", power_now=0, energy_now=40_000_000, energy_full=40_000_000)
        self.assertEqual(self.row()["watts"], 0)
        self.assertIsNone(self.row()["seconds"])

    def test_invalid_and_non_finite_measurements_are_unavailable(self):
        self.supply(type="Battery", capacity=101, power_now="nan", current_now="inf", temp="invalid",
                    energy_now=-1, energy_full="-inf", cycle_count=-1)
        row = self.row()
        for field in ("watts", "capacity", "energyWh", "fullWh", "cycles", "temperatureC"):
            self.assertIsNone(row[field], field)

    def test_absent_and_peripheral_batteries_do_not_affect_laptop(self):
        self.supply("mouse", type="Battery", scope="Device", capacity=5)
        self.supply("BAT1", type="Battery", present=0, capacity=1)
        self.supply(type="Battery", present=1, capacity=80)
        result = battery.collect(self.root)
        self.assertEqual(len(result["batteries"]), 1)
        self.assertEqual(result["capacity"], 80)

    def test_multiple_batteries_weight_percentage_by_energy(self):
        self.supply(type="Battery", energy_now=10_000_000, energy_full=20_000_000)
        self.supply("BAT1", type="Battery", energy_now=60_000_000, energy_full=80_000_000)
        self.assertEqual(battery.collect(self.root)["capacity"], 70)

    def test_adapter_rated_limit_is_not_reported_as_consumption(self):
        self.supply("AC", type="Mains", online=1, input_power_limit=65_000_000)
        self.supply("USB", type="USB", online=0, power_now=30_000_000)
        result = battery.collect(self.root)
        self.assertTrue(result["externalPower"])
        self.assertTrue(all(row["watts"] is None for row in result["adapters"]))
        self.assertEqual(result["batteries"], [])

    def test_current_adapter_power_is_reported_separately(self):
        self.supply("USB", type="USB", online=1, current_now=2_000_000, voltage_now=20_000_000)
        self.supply(type="Battery", status="Charging", power_now=25_000_000)
        result = battery.collect(self.root)
        self.assertEqual(result["adapters"][0]["watts"], 40)
        self.assertEqual(result["batteries"][0]["watts"], 25)
        self.assertTrue(result["charging"])

    def test_missing_sysfs_and_hot_removed_supply(self):
        self.assertEqual(battery.collect(self.root / "missing")["batteries"], [])
        node = self.supply(type="Battery")
        (node / "type").unlink()
        self.assertEqual(battery.collect(self.root)["batteries"], [])


if __name__ == "__main__":
    unittest.main()
