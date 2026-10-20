# Verification plan

Status: procedures only. Unexecuted procedures are not passing tests.

Executed authoring checks are recorded separately in [latest-results.md](latest-results.md). Run optional-planner contracts with `py -3 -m unittest discover -s tests -p "test_*.py"` on Windows or `python -m unittest discover -s tests -p 'test_*.py'` in a builder with Python already available. Python is authoring/builder tooling, not an automatic target dependency.

The experimental end-to-end procedure is [automation.md](../docs/automation.md). Each installer case starts with a new disposable disk and uses actual package/disk evidence; the builder's final status explicitly leaves runtime QA pending. Use zero/Git/JS/Python/combined, offline/failure and pre-confirmation cancellation cases before any real disk. Validate the ordinary-user login, TTY fallback and EFI fallback boot after reboot.

| Environment | Check | Evidence required |
| --- | --- | --- |
| Windows, read-only | Local Markdown link destinations, catalog IDs/defaults, paired Node/npm entry, wishlist warnings | Exact command/result; static inspection does not validate full YAML or package availability |
| Existing Arch VM, no installs | Installed versions, filesystem type, shipped configuration examples, package metadata | Tool versions and upstream revision; do not include secrets or machine disk IDs |
| Authorized Arch VM build | bash syntax and shellcheck, clean native-filesystem build, target/live package boundaries | Exit codes, compiler/tool versions, package inventories and ISO SHA-256 |
| Disposable QEMU/OVMF VM | UEFI boot and TTY fallback | Firmware/tool versions and boot log; graphics success remains a separate hardware test |
| Supported GPU hardware | M1 login, Foot, launcher, bar, files, Wi-Fi, audio, lock, portals, suspend/resume | Hardware/driver versions, each result and known defects |
| Two physical/accelerated monitors | M2 new-window mode vs existing overrides, local slot shortcuts, cursor focus, hotplug and geometry | Repeated steps, expected/actual results, restore after reboot |
| Authorized disposable installer VM | Zero/Git/JS/Python/combined/offline, unknown choices, Back/Next, failures and cancellation | Selection plan, explicit and full pacman inventories, dependency explanations, pre/post disk snapshots |
| Synthetic storage/EFI VM | Hibernated/unclean NTFS, encrypted data, protected partitions, safe eject and boot preservation | No unexpected write/format/EFI mutation; recovery outcome |
| Laptop | One power manager, AC/battery switching, idle/load/thermal benchmarks | Fixed brightness/workload/kernel, baseline and repeated samples; no universal improvement claim |

Do not attach host disks to installer test VMs. Review disk targets before approving any disk write. A clean cancellation test compares all disposable disk contents and partition tables before and after cancellation, including cancellation after Back/Next navigation.

Record results with date, source revision, environment, command or exact manual steps, exit code/observed outcome, limitations and next action. Keep generated images, VM disks and private logs outside tracked source.
