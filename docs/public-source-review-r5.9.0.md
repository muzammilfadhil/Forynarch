# Public source review: R5.9.0

Scope: the current source export and the original repository's one-commit Git
history. No repository visibility change, push or hosted release was performed.

## Included

- Original source/configuration, build and installer scripts, user/developer
  documentation, examples and eight actual ISO screenshots.
- Creator attribution as a source constant, complete upstream credit links,
  retained third-party licenses and the proposed original-code license text.
- GitHub source-test workflow with read-only permissions, pinned official
  checkout/setup-python revisions and no persisted checkout credentials.
- Exporter and package-inventory tools, with tests covering ignored tracked
  files, refusal to overwrite destinations, hashes and exact package metadata.

## Excluded

`.git` history, authoring sessions, local Serena/Codex state, generated images,
VM disks/state, build/package caches, logs, credentials, recovery keys, GIPHY
API keys, private local application packages and the unverified Kath media.
These paths are protected by `.gitignore`. The exporter also evaluates ignore
rules against tracked files; ordinary `git archive` would not do that.

The Kath MP4/PNG and two Serena metadata files were removed from the current Git
index while preserving their local copies. Their prior commits remain in the
original repository. Publishing that existing history still requires a separate
rights/history decision. A fresh repository made from the clean export carries
none of those old objects; it is prepared locally with no remote configured.

## Checks

Gitleaks **8.30.1** was downloaded from its official release and verified against
the published SHA-256 checksum. Redacted reports remain in ignored local output.
The source export and reviewed history scans have no unresolved findings. The
history scanner's sole original finding was the literal synthetic test value
`FixtureKey123`; its exact value is narrowly allowlisted. A synthetic web-app
UUID variable was renamed from `KEY` to `WEBAPP_ID` to prevent another false
positive in the current tree. No real credential was allowlisted.

Scanners do not guarantee that every secret or licensing problem is detectable.
The binary ISO is covered by source/build separation, staged-file review and
package inventories rather than a claim that all binary contents were scanned
as text. See [release verification](release-r5.9.0.md).

## Remaining publication decisions

The original-code license proposal still needs the owner's decision. Public
binary hosting also requires satisfying corresponding-source obligations for
the exact distributed packages. Those are explicit release gates in
[publishing](publishing.md), not completed legal certification. The public image
uses original navy artwork; the local Kath video and Mudil Music binary stay
outside this release. Firmware and application trademarks retain their own
terms.
