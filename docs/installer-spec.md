# Forynarch — Installer and Software Selection Specification

> Design draft · Creator: Muhammad Muzammil Fadhil · 14 October 2026

15 October: [standalone setup](standalone-installer.md) replaces the embedded
Settings wizard. It implements Welcome, Connection, Location, Keyboard, Storage,
Account, Drivers, Software and Review as a separate Live application, with
read-only inventory and a confirmed dedicated-disk ext4 execution path. Passwords
are handed to the privileged child over private stdin. Actual offline VM install,
EFI boot, accounts and login passed; manual/alongside layouts, encryption and
hardware driver acceptance remain incomplete. See the
[implementation evidence](production-desktop-review-2026-10-15.md).

Forynarch can be the only OS on a computer. Alongside installation can preserve
another Linux system or Windows. Installation belongs in its own application;
disk administration remains in Settings and the standard partition editor.

## Product requirement

A Forynarch installation should leave the user with a working lightweight Linux desktop. **Git, Node.js, npm, Python, IDEs, containers and SDKs must not be installed as explicit optional apps unless the user selects them.** The mandatory kernel, package manager, network/audio/desktop dependencies are not presented as optional toggles.

## Proposed UX

1. Welcome + language.
2. Network check. Network optional for **minimal core**; extra downloads require internet unless bundled.
3. Region/keyboard.
4. Disk layout and existing system detection with conservative, explicit data-loss warnings.
5. User/password.
6. **Choose your software**: Required core shown as installed by default and locked; browser/extras and each developer toolkit unchecked initially.
7. Summary with exact user choices, package download status, disk operations, selected bootloader and explicit confirmation.
8. Install target minimal filesystem, selected packages, then system configuration; report errors with actionable options.
9. Reboot or continue live session.

### Wireframe text

```text
FORYNARCH                        Setup · Software
─────────────────────────────────────────────────────────────
  Included with Forynarch (required)
  ✓ Hyprland desktop, terminal, file manager, network, audio

  Choose optional developer tools     (None selected by default)
  [ ] Git                        Version control
  [ ] Node.js + npm              JavaScript & web development
  [ ] Python                     Python runtime
  [ ] Neovim                     Terminal editor
  [ ] Code OSS                   GUI editor
  [ ] Docker                     Containers (needs service setup)
  [ ] Podman                     Rootless containers
  [ ] Rust (rustup)              Rust toolchain bootstrap
  [ ] Go                         Go compiler

  Additional applications
  [ ] Firefox                    Web browser

  Offline: unavailable selections should be disabled and explained.
  Summary: 0 optional groups selected             [Back] [Next]
```

## Functional contract

- Explicit `default: false` applies to **each** optional group and all frontend variants, including after navigating back and returning to the step.
- Every package group has a unique stable ID and a validated `packages` list.
- Group `nodejs-npm` installs **both** `nodejs` and `npm` as a single understandable selection.
- No `select all` implicit behavior. Avoid hidden automatic editor/SDK metapackages.
- Before executing package operations, build a `planned_package_operations` list from selected groups, deduplicate, validate, and show a summary.
- A package can be transitively installed for a mandatory OS dependency; disclose this in logs. That does not constitute permission to auto-enable a developer **group**.
- If offline, minimal core is still available from installation media; do not promise extra groups if package files are not locally present.
- Never place user passwords, tokens, secrets, serial numbers or exact disk IDs into logs or telemetry.
- User choices must be preserved across Back/Next; Cancel must not initiate disk writes.
- Every destructive disk operation requires specific, explicit final consent.

## Architecture / module bridge

`packages/optional-catalog.yaml` is the **human-readable design catalog**, not direct Calamares configuration. Implement a tested conversion into the selected Calamares `netinstall` / `packagechooser` module config and `packages` execution. Keep version-sensitive syntax outside the catalog. Do not assume the `default` field is natively recognized by Calamares.

Calamares `unpackfs` can copy what is included in an image. For a truly minimal target with unchecked developer tools, build a dedicated minimal target filesystem; the live environment may still need extra tools. Test the installed target with `pacman -Q` and end-user commands.

## Acceptance tests

| Case | Selection | Expected |
| --- | --- | --- |
| Zero | None | Core desktop boots, no *explicit* developer add-ons |
| Git | Git only | Git works; JS/Python groups unselected |
| JS | Node.js + npm | `node` + `npm` work; no Git group auto-selected |
| Python | Python only | `python` works; Git/JS groups not selected |
| Combined | Git + Python | Both work, no unexpected developer group |
| Offline | None | Core installer succeeds without network |
| Offline add-on | Node.js when unavailable | Disabled with explanation, not silently skipped |
| Cancel | User cancels at summary | No disk change |
| Unsupported | Missing mandatory driver / firmware | Installation stopped with clear error, not a broken boot promise |

An automated matrix on temporary VM disks is required before describing the installer as usable.
## Experimental existing-OS VM support

The optional catalog group `experimental-os-vm` is unchecked by default. It
installs QEMU, OVMF, swtpm and fixed disk-isolation tools only after the user
selects it in software choices. It does not select developer toolchains, open an
existing OS volume, create a VM profile or enable virtualization automatically.
The installed Settings page provides separate activation and per-launch review.
Existing-OS disk access is independent of the installer destination and never
authorizes repartitioning, formatting or host EFI changes. See the
[VM contract](experimental-os-vm.md) for supported layouts and consent rules.
