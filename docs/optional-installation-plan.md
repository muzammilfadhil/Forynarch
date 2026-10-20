# Optional installation implementation plan

Status: proposed contract, not Calamares configuration or an executable installer.

Implementation progress: a strict pure preview planner now exists in [package_plan.py](../scripts/package_plan.py), with [contract tests](../tests/test_package_plan.py). The catalog uses JSON serialization (valid YAML 1.2) to avoid a parser dependency. Empty/default/selection validation and offline rejection are implemented. Dependency resolution, repository/signature validation, immutable execution plans and Calamares integration remain pending; preview output always forbids execution.

Follow-up: the separate [experimental CLI pipeline](automation.md) implements a bundled snapshot, pacman transaction review, signed prefetch, disk consent and installed-inventory checks. These paths have not executed in Arch or on a disk. The Calamares frontend and full safety/offline/error matrix are still pending; the original design gates below remain required.

## Package boundaries

Build the core target filesystem independently of the live environment. It must boot and support the M1 desktop without selecting a developer group. Installer/recovery tooling belongs to the live manifest. Neither desktop.txt nor development.txt is an installation manifest. Do not repair live-image leakage by blindly deleting runtimes that other packages need.

For each frozen package snapshot, record target explicit packages, their dependency closure and justification, live-only additions, optional groups and dependency additions. The acceptance rule distinguishes user selections from dependencies: an unselected runtime is only acceptable when its mandatory dependency chain is documented and reviewed. Prefer core components that avoid such runtimes where practical.

## Pure planning layer before installer integration

1. Parse the canonical JSON-serialized YAML catalog strictly in the builder/live tooling. Reject duplicate keys, unknown schema versions, duplicate IDs, missing/true defaults, empty package lists, invalid package names and unsupported categories. If general YAML syntax is introduced later, use a real safe YAML parser and preserve these checks.
2. Start a fresh install with an empty set. Preserve choices on Back/Next, never restore another user's saved selections, and reject unknown selection IDs.
3. Resolve selected IDs to a sorted, deduplicated explicit package list. Empty selections produce no optional package operations. Node/npm remains one selection containing both packages.
4. Resolve package availability, signatures, dependency closure, conflicts and download requirements against the same repository snapshot used for the target. Selecting pip may require Python; show that dependency even if the Python group itself is unchecked. Editors or containers can also introduce dependencies; do not silently enable their groups.
5. Record an immutable reviewed plan containing core payload identity, selected IDs, explicit packages, additional dependencies with reasons, availability and download sizes. Keep account secrets and disk identifiers outside package logs. Disk review still shows the exact target locally to the user.
6. Require the final summary to match execution. Changed selections, payload or repository metadata invalidate the plan and require a new summary before disk writes. Revalidate cached package integrity before execution.

## Version-tested Calamares adapter

Pin the installed Calamares release and inspect its shipped module configurations. Compare netinstall and packagechooser behavior with the packages executor. Choose the smallest adapter that can preserve empty defaults, stable IDs, offline disabling and summary fidelity. Translate catalog defaults explicitly; do not assume Calamares understands the catalog's fields.

Prototype only selection and plan generation first. Test front-end defaults and back-navigation using the real module UI. Introduce target extraction, package execution, accounts and bootloader only in an isolated disposable VM after their operations are approved. Use the separate core payload for unpacking, never the complete live rootfs.

Package selection alone does not authorize Docker service activation, group membership changes, Rust toolchain downloads, network services or IDE extensions. Represent additional actions separately with clear consent and validation. Pacman installs only planned explicit optional packages plus required dependencies; no shell interpolation of untrusted catalog/selection input.

## Offline and failure behavior

The local verified core payload is mandatory for offline installation. An optional group is available offline only when its entire dependency closure and signature data are bundled and verified. Otherwise disable it with an explanation. A network/cache/signature/conflict failure before confirmation blocks the plan; after writes begin, stop with an actionable error and recovery path. Never report selected packages as installed after a failure or silently discard a selection.

## Delivery sequence and verification

| Stage | Deliverable | Gate |
| --- | --- | --- |
| A | Catalog validator and pure planner, builder/live only | Empty/Git/JS/Python/combined selections; malformed/default-enabled/duplicate/unknown cases rejected |
| B | Target manifest and independent payload | Core boots; explicit/transitive inventory reviewed; no unexplained live-only leakage |
| C | Calamares selection adapter | UI initially empty, Back/Next preserved, offline unavailability explained, summary matches plan |
| D | Authorized disposable-disk install | Zero, Git, JS, Python, combined and offline installs reboot; package inventories match reviewed plans |
| E | Failure/safety matrix | Cancel is disk-neutral; network loss, signature rejection, disk full and bootloader failures reported; synthetic Windows EFI preserved |

Tests must include a live-only sentinel package absent from the independent target. Compare pacman explicit and total inventories and command availability; presence/absence alone does not prove why a dependency was installed. Retain plan-to-installed diffs and reviewed dependency exceptions. No installer release claim before the complete VM matrix and physical desktop gate pass.
