# R5.8.7 installed-system patch

This update follows R5.8.6. It removes the extra Hyprbars titlebar from Mudil
Music, corrects Mudil's Linux MPRIS playback clock, preserves embedded timed
lyrics, and uses configured web-app names and website icons in the application
bar and floating titlebars. No ISO build is required.

## Install

Copy `forynarch-r5.8.7.tar.gz` and its `.sha256` file to Forynarch, then run as
your normal desktop user:

```sh
sha256sum --check forynarch-r5.8.7.tar.gz.sha256
tar -xzf forynarch-r5.8.7.tar.gz
cd forynarch-r5.8.7
bash apply.sh --check
bash apply.sh --apply
```

Sign out and sign back in. Reopen Mudil Music. A compositor reload cannot
replace an already loaded native plugin. The patch checks the exact Hyprland
package version before changing files; its plugin was built for 0.56.2-4.

The patch upgrades an **already installed** Mudil Music older than 3.9.0-3 using
the bundled native package. It never installs an unselected application or
downgrades a newer Mudil version. `--desktop-only` skips the package upgrade
and is intended for isolated desktop testing, not the playback-clock fix.

## Changes and cost

- Mudil retains its own controls. Other eligible floating applications retain
  the existing minimize, maximize, fullscreen and close controls.
- The vendored audio_service_mpris 0.2.1 bridge derives Position from a monotonic
  clock, freezes on pause/buffering, applies playback rate and emits Seeked
  after position discontinuities. It adds no periodic process or network call.
  Reproduction: run `scripts/patch-mudil-mpris.py APP UPSTREAM_LIBRARY` before
  building Mudil's Linux package. The upstream license remains in the vendor.
- Embedded LRC timestamps, multiple timestamps and millisecond offsets are
  parsed. Plain embedded lyrics remain the fallback while an enabled lyrics
  widget requests timed lyrics. Disabled/hidden lyrics make no requests.
  Accurate line highlighting requires timed lyrics and correct player metadata;
  ordinary text cannot supply line timestamps.
- Web-app launchers gain StartupWMClass. Website icons are read from HTML icon
  links, then bounded favicon fallbacks. HTTPS transfers and image dimensions
  are bounded. Existing missing icons get one bounded refresh during patching;
  launching an app never fetches icons. Unreachable sites keep a generic icon.
- A small downstream `hyprbars:title` rule displays the saved web-app name
  without changing the browser URL or real page title. The backend also maps
  Chromium-prefixed classes and owned browser profile paths to app identity.
- Mudil's native application icon replaces initials. Accounts, profile IDs,
  cookies, and browser storage remain in their existing directories.

Affected source: `config/hypr/titlebars.lua`, `MediaModel.qml`, `Lyrics.js`,
`RunningApplications.qml`, the window-control and web-app helpers, native
Hyprbars build patch, optional Mudil package manifest and patch packaging.
Source integration is ready for a later ISO build. No new core developer
toolchain or resident service is introduced.

## Verification and limits

Focused results are recorded in `tests/latest-results.md`. The music bridge
test reads Position over a real private D-Bus session, exercises pause, seek
signals, playback rate and track reset. Shell tests cover isolated browser
profiles. QML tests cover timing/line selection and disabled-lyrics behavior.

Physical audio playback with the user's Spotify/Mudil account, site-specific
favicon changes and an installed-hardware idle RAM benchmark remain hardware
checks. The patch does not assert a new measured installed RAM result.

## Restore

The apply output prints timestamped system and user backup directories. Use
the `restore.py` saved inside each directory, with the matching privilege:

```sh
python ~/.local/state/forynarch/patches/r587-TIMESTAMP/restore.py restore ~/.local/state/forynarch/patches/r587-TIMESTAMP
sudo python /var/lib/forynarch/patches/r587-TIMESTAMP/restore.py restore /var/lib/forynarch/patches/r587-TIMESTAMP
```

Sign out and back in after restoration. These restore shipped files, not
package transactions or generated web-app icons/launchers. To revert Mudil,
review and reinstall the previous package with `pacman -U`; do not delete its
profile. The generated web-app metadata can be refreshed with
`forynarch-webapp-assets sync` after restoring the desired helper version.
