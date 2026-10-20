import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("package_plan", ROOT / "scripts/package_plan.py")
planner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(planner)


class OptionalPackageContract(unittest.TestCase):
    def setUp(self):
        self.catalog = planner.load_catalog(ROOT / "packages/optional-catalog.yaml")

    def test_empty_has_no_optional_packages_and_cannot_execute(self):
        plan = planner.create_plan(self.catalog)
        self.assertEqual(plan["selected_group_ids"], [])
        self.assertEqual(plan["explicit_optional_packages"], [])
        self.assertIs(plan["execution_allowed"], False)
        self.assertIsNone(plan["additional_dependencies"])

    def test_selection_matrix(self):
        cases = [(["git"], ["git"]), (["nodejs-npm"], ["nodejs", "npm"]),
                 (["python"], ["python"]), (["git", "python"], ["git", "python"]),
                 (["nodejs-npm", "python"], ["nodejs", "npm", "python"])]
        for selected, expected in cases:
            with self.subTest(selected=selected):
                self.assertEqual(planner.create_plan(self.catalog, selected)
                                 ["explicit_optional_packages"], expected)

    def test_all_groups_require_explicit_selection(self):
        for group in self.catalog["groups"]:
            with self.subTest(group=group["id"]):
                self.assertIs(group["default"], False)
                self.assertEqual(planner.create_plan(self.catalog, [group["id"]])
                                 ["explicit_optional_packages"], sorted(group["packages"]))

    def test_repeat_selection_deduplicated(self):
        plan = planner.create_plan(self.catalog, ["python", "git", "git"])
        self.assertEqual(plan["selected_group_ids"], ["git", "python"])
        self.assertEqual(plan["explicit_optional_packages"], ["git", "python"])

    def test_shared_packages_deduplicated(self):
        self.catalog["groups"][0]["packages"].append("python")
        self.assertEqual(planner.create_plan(self.catalog, ["git", "python"])
                         ["explicit_optional_packages"], ["git", "python"])

    def test_unknown_selection_rejected(self):
        with self.assertRaises(planner.PlanError):
            planner.create_plan(self.catalog, ["everything"])

    def test_offline_empty_allowed(self):
        self.assertEqual(planner.create_plan(self.catalog, offline=True)
                         ["explicit_optional_packages"], [])

    def test_offline_optional_rejected(self):
        with self.assertRaises(planner.PlanError):
            planner.create_plan(self.catalog, ["git"], offline=True)

    def test_enabled_or_nonboolean_default_rejected(self):
        for value in (True, 0, "false", None):
            with self.subTest(value=value):
                catalog = copy.deepcopy(self.catalog)
                catalog["groups"][0]["default"] = value
                with self.assertRaises(planner.PlanError):
                    planner.validate_catalog(catalog)

    def test_duplicate_group_rejected(self):
        self.catalog["groups"].append(copy.deepcopy(self.catalog["groups"][0]))
        with self.assertRaises(planner.PlanError):
            planner.validate_catalog(self.catalog)

    def test_missing_or_extra_fields_rejected(self):
        for mutation in ("missing", "extra"):
            catalog = copy.deepcopy(self.catalog)
            if mutation == "missing":
                del catalog["groups"][0]["default"]
            else:
                catalog["groups"][0]["command"] = "install everything"
            with self.subTest(mutation=mutation), self.assertRaises(planner.PlanError):
                planner.validate_catalog(catalog)

    def test_unknown_schema_and_unsafe_policy_rejected(self):
        for value in (2, True, "1"):
            catalog = copy.deepcopy(self.catalog)
            catalog["schema_version"] = value
            with self.subTest(version=value), self.assertRaises(planner.PlanError):
                planner.validate_catalog(catalog)
        self.catalog["policy"]["user_must_opt_in"] = False
        with self.assertRaises(planner.PlanError):
            planner.validate_catalog(self.catalog)

    def test_package_injection_and_empty_list_rejected(self):
        for packages in ([], ["--needed"], ["git;echo secret"],
                         ["$(id)"], ["../git"], ["git", "git"], [None]):
            catalog = copy.deepcopy(self.catalog)
            catalog["groups"][0]["packages"] = packages
            with self.subTest(packages=packages), self.assertRaises(planner.PlanError):
                planner.validate_catalog(catalog)

    def test_js_pair_cannot_be_split(self):
        group = next(group for group in self.catalog["groups"] if group["id"] == "nodejs-npm")
        group["packages"] = ["nodejs"]
        with self.assertRaises(planner.PlanError):
            planner.validate_catalog(self.catalog)

    def test_invalid_selection_type_rejected(self):
        for selection in ("git", [None], {"git": True}):
            with self.subTest(selection=selection), self.assertRaises(planner.PlanError):
                planner.create_plan(self.catalog, selection)

    def test_planning_does_not_mutate_catalog(self):
        original = copy.deepcopy(self.catalog)
        planner.create_plan(self.catalog, ["git"])
        self.assertEqual(self.catalog, original)

    def test_catalog_identity_changes_with_choices_definition(self):
        before = planner.create_plan(self.catalog)["catalog_sha256"]
        self.catalog["groups"][0]["description"] = "Updated description"
        self.assertNotEqual(before, planner.create_plan(self.catalog)["catalog_sha256"])

    def test_duplicate_json_keys_and_malformed_input_rejected(self):
        for content in ('{"groups": [], "groups": []}', 'schema_version: 1'):
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "catalog.yaml"
                path.write_text(content, encoding="utf-8")
                with self.assertRaises(planner.PlanError):
                    planner.load_catalog(path)

    def test_cli_empty_and_invalid_selection(self):
        command = [sys.executable, str(ROOT / "scripts/package_plan.py")]
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["explicit_optional_packages"], [])
        result = subprocess.run(command + ["--select", "unknown"],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertIn("unknown selection", result.stderr)


if __name__ == "__main__":
    unittest.main()
