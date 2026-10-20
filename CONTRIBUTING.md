# Contributing

[the vision](docs/vision.md),
[architecture](docs/architecture.md) and [installer specification](docs/installer-spec.md)
before changing behavior. Keep all shipped interface text in English.

Use a branch and a focused pull request. Describe the user-visible problem,
change, verification and remaining limits. Preserve third-party notices and
record the source revision of imported code or assets. Do not submit generated
ISOs, VM disks, package caches, credentials, recovery keys or personal logs.

Run the portable tests from the repository root:

```sh
python -m unittest discover -s tests -p 'test_*.py'
python scripts/hotkeys.py --check
```

Native tests require Arch Linux and their documented dependencies. A skipped
test is not a pass. Build only on a Linux-native filesystem; follow
[the build guide](docs/wiki/build-and-test.md). Use disposable block fixtures for
storage tests. Do not test formatting or passthrough on personal disks.

Keep developer toolchains opt-in in the installed target. Desktop changes must
preserve reduced motion and low-power modes. Measure installed idle RAM using
`MemTotal - MemAvailable`; the limit is 3,000,000,000 bytes, with swap reported
separately. Live USB RAM is a separate measurement.

The project-wide license decision is pending; see
[the publication checklist](docs/publishing.md) before accepting contributions
for redistribution under a new project license.
