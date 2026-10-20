# Package policy

`desktop.txt` and `development.txt` are wishlists. They are never fed to pacman or archiso automatically. `target-core.proposed.txt` is a core candidate consumed only by the explicitly approved automation pipeline with runtime validation. `live-only.proposed.txt` remains a review proposal and is not executed.

`optional-catalog.yaml` is the single canonical optional catalog. It now uses JSON serialization, which is valid YAML 1.2. This permits strict parsing with Python's standard library without installing a YAML library. Keep JSON syntax in this file; the planner rejects duplicate keys and unsupported fields. It remains a design catalog, not Calamares configuration.

`scripts/package_plan.py` is **authoring/builder tooling only**. Python is already available on the authoring host; it is not added to the installed target. Plans are previews: dependencies, signatures, repository snapshot, package availability and sizes are unresolved, so every plan has `execution_allowed: false`. No package installation or shell execution is implemented.

The separate experimental [automation pipeline](../docs/automation.md) now consumes these validated group choices, computes a real pacman transaction from bundled core/database metadata, verifies downloads, requires disk-specific approval and checks final inventories. A preview's `execution_allowed: false` is never treated as permission. The authoring planner itself remains non-executing.

Examples from Windows:

```powershell
py -3 scripts/package_plan.py
py -3 scripts/package_plan.py --select git
py -3 scripts/package_plan.py --select nodejs-npm --select python
py -3 scripts/package_plan.py --offline
py -3 -m unittest discover -s tests -p "test_*.py" -v
```

From a builder with Python already installed, use `python` instead of `py -3`. All optional groups currently require online dependency validation; offline nonempty selections fail explicitly. No selections produce an empty optional package list. Selecting pip includes only its explicit package in the preview; its Python dependency must be resolved and shown later.

Review the current stable Arch repositories, not testing or AUR, for M1. Separate hardware-specific firmware/drivers and the selected bootloader from the common desktop package set. Document mandatory dependency chains before accepting developer runtime exceptions.
