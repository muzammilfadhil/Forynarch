# Installer output transport correction: R5.8.1

The reported R5.8 screenshot stops at `download` with an unknown executor exit
code and the generic preflight error. This means the privileged helper ended
without publishing its final process result. It does not establish a GPT or
account validation problem.

The R5.8 helper reproduces this state when a child writes a non-UTF-8 byte after
the download marker: Python raises `UnicodeDecodeError`, the last stage stays
`download`, and no terminal event is published. The original laptop log was not
available; this proves a matching failure path, not the exclusive cause of that
machine's failure.

## Changes

- Read child output as bytes and decode explicitly as UTF-8 with replacement for
  invalid bytes. Account input still uses strict UTF-8 encoding. Logs are UTF-8
  independently of the caller's locale. Password redaction remains in place.
- Continue draining the actual process when writing its log or status fails.
  Preserve its exit code and bounded output in the UI, with a separate I/O warning.
  A log-write error does not interrupt an active filesystem operation.
- Require the executor completion marker as well as exit 0. Missing completion
  or unreadable output leaves disk state unknown.
- When the helper exits without a terminal event, Review clears the stale
  pre-write status, retains the failed stage and shows the helper exit separately
  from the unknown executor exit. It does not blame disk/account fields.

Affected files: `scripts/forynarch-install-system.py`, installer `shell.qml`,
executor regression tests and native execution fixtures. Pacman/partitioning
commands, optional selections, core package inventory and installed desktop
services are unchanged from R5.8.

## Verification and limits

The byte-corruption reproducer on the unmodified R5.8 helper produced
`UnicodeDecodeError`, last stage `download`, terminal report false. New tests cover
invalid output bytes, a full log filesystem, a failed status write and a missing
completion marker. Native QML also exercises a helper that disappears after
reporting a pre-write download stage.

The test environment remains pacman 7.1.0, Quickshell 0.3.2, Qt 6.12 and
util-linux 2.42.4 with the cached 18 October Arch snapshot. This correction does
not certify the physical laptop or claim a new installed memory measurement.
R5.8's repository/Mudil acceptance and incomplete full Flatpak acceptance remain
as described in [the R5.8 review](installer-r5.8-review.md).

Antislop DURING: the existing Review controls, colors, geometry and motion are
retained. Error states use explicit text and the existing keyboard-accessible
details/copy controls. No asset, service or idle process is added.

## Results

- **54 targeted tests passed**: 35 installer tests, five prepared-install tests,
  two executable-review tests and 12 partition-preparation tests. Bash syntax,
  ShellCheck and the changed-file whitespace check returned exit 0.
- The **15 executor tests also passed under forced ASCII locale**, with Python
  UTF-8 mode and locale coercion disabled. The byte-corruption test simultaneously
  verifies exact non-ASCII account-input bytes and retained child exit 17.
- Native Wayland setup, successful execution, download failure, Flatpak failure
  and missing-final-report fixtures passed. The latter retains helper exit 23,
  an unknown executor exit, the download stage, stderr details and unknown disk
  state without a duplicate error banner. Test confirmation never targets disks.

The unmodified R5.8 helper in the actual Live image also reproduced the same
`UnicodeDecodeError` when valid UTF-8 output was received under an ASCII caller
locale. This confirms that caller-locale dependence alone can trigger the
missing-report path; invalid package output is not required.

## Final image

The corrected image is `forynarch-2026.10.18-blue-hour-r5.8.1.iso`, built on
19 October from the cached 18 October Arch snapshot. `mkarchiso` exited 0.
Its **3,839,197,184 bytes** match the builder's SHA-256:

```text
cbd6d80911a403825a3cafd54d26e6a9e18861b7d102f2b8b7feb624900b57d8
```

SquashFS and final Live checks confirm the CLI, helper and installer QML match
the current source. The independent target remains **573 core packages**, without
the optional QA selections. UEFI boot reaches the Live desktop and Try/Install
Welcome, with the executor available and no target disk attached.

The actual helper from this final image was invoked with a disposable child
under an ASCII caller locale. Valid UTF-8 output remained intact, child exit 17
was retained and a terminal `failed/download` report was published. This is the
same environment that made the previous Live helper lose its final report.
Screenshot and raw test reports are ignored generated output under
`out/virtualbox/r581-*`.
