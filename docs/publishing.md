# Preparing a public release

Release candidate: **R5.9.0**. Creator: **Muhammad Muzammil Fadhil**.
The About page stores this attribution as a source constant rather than a user
preference. Desktop preferences and documented configuration files remain
editable. Forks must preserve applicable copyright and upstream notices.
The constant is not a restriction on editing source or changing a fork's
branding; original copyright attribution must be retained where required.

## Before uploading source

- Choose the license for original Forynarch code. GPL-3.0-or-later is proposed
  in `licenses/PROPOSED-Forynarch-GPL-3.0.txt`; it is not yet a license grant.
  The owner must approve it before it becomes the root `LICENSE`.
- Use `python scripts/export-public-source.py --output out/public-source` to
  create a source tree and ZIP without `.git` history or ignored local files.
  The command refuses an existing output directory and does not modify the
  working repository. Review `SOURCE-MANIFEST.json` and the exported tree.
- Scan that export with Gitleaks and review any findings. Scan all Git history
  separately if preserving history. A scanner cannot guarantee the absence of
  secrets or establish rights to redistribute an asset.
- The original history contains Kath video/still artwork. Removing them from
  the current index does not remove them from old commits. **Do not publish the
  existing history** until those rights are resolved or the history is reviewed
  and sanitized. A fresh repository initialized from the clean export avoids
  carrying that history. No history rewrite or force-push is part of this task.
- Keep `out/`, `work/`, private keys, logs, VM state, API keys, recovery keys and
  locally built application packages private. The export checks tracked files
  against the current ignore rules as well as filtering untracked files.

## Before uploading an ISO

- Verify the ISO against its SHA-256 file and boot that exact image.
- Publish release notes with the tested environment and unresolved issues.
  Do not describe a Live VM measurement as an installed hardware RAM benchmark.
- Export exact package versions, upstream URLs and license metadata from both
  the installed target and Live root. Archive corresponding sources and build
  modifications required by each applicable license alongside the binaries.
  Source URLs and package metadata alone are not a completed source offer.
  See the [GNU GPLv3 distribution guidance](https://www.gnu.org/licenses/quick-guide-gplv3.html).
- The ISO contains separately licensed Arch packages and firmware. A root
  Forynarch license does not relicense the ISO as a single work.
- Public login artwork is `assets/wallpapers/navy.svg`. The local Kath MP4/PNG
  and the separately maintained Mudil Music binary are excluded. Restore either
  only after documenting its source, license and redistribution permission.
- Screenshot only a clean guest desktop. Exclude personal account names,
  SSIDs, notifications, files, tokens and the Windows host desktop.

## Publication status

This preparation does not push to GitHub, change repository visibility, create
a hosted release or certify hardware. Record completed checks and remaining
publication gates in `docs/release-r5.9.0.md`. Decide repository visibility only
after reviewing the clean export, license and binary-source obligations.
