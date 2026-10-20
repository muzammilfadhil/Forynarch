# Installed-system patch R5.8.6

This patch is for the installed Forynarch R5.8.5 desktop. No ISO rebuild or
reinstallation is needed. Apply it as the normal desktop user, with internet
available for the selected browser and firmware packages.

## Apply

Copy `forynarch-r5.8.6.tar.gz` to a USB drive or another location readable from
Forynarch. Extract it in Downloads, then open a terminal in the extracted folder:

```sh
bash apply.sh --check
bash apply.sh --apply
```

The first command only verifies and displays the patch. The second requests sudo
for system files and package installation. Keep the normal pacman/yay review
prompts. Reopen applications, or sign out and sign back in, after it completes.
Restart once after installing missing audio firmware.

`bash apply.sh --apply --desktop-only` applies the file changes without installing
Chrome, yay, firmware or build tools. This is also the VM verification path.

## Changes

- GTK minimize/maximize/close controls move to the upper right. Existing theme,
  font and unrelated GTK preferences are retained.
- Hyprbars adds upper-right minimize, maximize, fullscreen and close controls
  to floating windows, including Alacritty and isolated Chrome web apps. Known
  GTK/browser windows retain their native controls instead of a duplicate bar.
  Double-click the added titlebar to maximize; drag it to move the window.
  Tiled windows do not get this extra bar. The existing window-control helper
  handles minimization and restoration through the hotbar/Alt+Tab.
- PipeWire sockets and WirePlumber start explicitly in the user session. The
  full patch installs SOF firmware, ALSA UCM profiles and ALSA utilities. It does
  not clear saved device routes, force-enable disabled hardware or unmute mics.
- The full patch installs **yay-bin**, then the AUR **google-chrome** package
  and sets Chrome as the user's default browser. `google-chrome` already
  packages Google's binary; there is no need to invent a `google-chrome-bin`
  package name. Git/base-devel are explicit prerequisites of this opt-in patch,
  not additions to the installed core manifest. Existing browsers and their
  account profiles are not removed. Web-app profiles stay isolated.
- Drive discovery recognizes BitLocker aliases and their unlocked mapper
  devices. Unlock accepts a password or recovery key over stdin, requests a
  read-only mapping through UDisks, and never saves the credential. Mounting
  remains an explicit action. Unmount before choosing Lock drive.
- The included Windows drive map uses GPT partition GUIDs read on Windows.
  Linux shows the same C:/D:/E: aliases even when device order changes. Aliases
  only affect presentation/bookmarks; actual mounts remain Linux paths. No
  partition is renamed, reformatted or mounted by applying the patch. Non-GPT
  drives without a reliable cross-OS identifier can still be assigned manually.
- The lock screen uses Kath artwork, Forynarch branding, a clock and the same
  restrained blue highlights as login. It uses Hyprlock's secure session lock,
  preserving running applications. **SDDM is the login greeter, not this lock
  implementation.** Logout continues to return to SDDM. The lock background is
  static to avoid running another video decoder alongside the desktop.
  On VirtualBox, lock fade capture is disabled to avoid its screencopy/DMABUF
  protocol failure. Physical hardware retains the normal fade animations.
- Music position stays bound to the selected MPRIS player, so paused seeks,
  player changes and track restarts update the widget. While visible and playing,
  refresh is 500 ms, or 250 ms for enabled lyrics. Hidden/paused widgets do not
  run the playback timer; disabled lyrics do not trigger online searches. This
  covers Mudil Music, Spotify and other players exposing MPRIS position; a
  browser player must enable its media-session integration.

## BitLocker

In Windows, obtain the matching 48-digit recovery password or a configured
BitLocker password before switching systems. A TPM-only auto-unlock does not
provide Linux with that credential. The patch does not bypass BitLocker or
change its protectors. Keep recovery credentials out of logs and patch files.
Use a full Windows shutdown before accessing Windows volumes. The UI unlocks
read-only by default and offers no hibernation removal, repair or forced writes.

Find a recovery key using [Microsoft's recovery guide](https://support.microsoft.com/en-us/windows/security/encryption/find-your-bitlocker-recovery-key).
The patch uses the documented [UDisks unlock/read-only interface](https://storaged.org/doc/udisks2-api/latest/udisksctl.1.html).

## Backup and restore

The script prints exact user and system backup paths and restore commands.
User backups are under `~/.local/state/forynarch/patches/`; system backups are
under `/var/lib/forynarch/patches/`. Restore each scope with its printed command,
then restart the desktop session. Restoration replaces patched file contents
with their pre-patch versions; back up any edits made after patching first.
Installed packages and browser profiles remain installed during rollback.

## Build integration and limits

The titlebar binary is built against Hyprland **0.56.2-4**, SDK commit
`efb50993780079460b0cbed1363e2166a2de1d9f`. An ABI mismatch refuses plugin
loading. After updating Hyprland, rebuild the plugin for that release before
loading it. Builder-only `scripts/build-titlebars.sh` uses upstream's reviewed
0.56.2 pin `7644cecdb947060682891a0db2a0cdc5c0b9e704`.

Source changes are integrated into the normal future ISO pipeline, including
audio firmware and titlebars. No ISO is built for this patch. Chrome/yay remain
an explicit installed-patch choice; the current installer browser catalog is
unchanged. AUR availability and actual hardware audio require the user's Linux
session. No physical BitLocker volume, recovery key or personal disk is used
for development testing.

Credits: [Hyprland/hyprbars](https://github.com/hyprwm/hyprland-plugins/tree/7644cecdb947060682891a0db2a0cdc5c0b9e704/hyprbars)
(BSD 3-Clause, license included), [yay](https://github.com/Jguer/yay), existing
[SDDM Astronaut/Kath](https://github.com/Keyitdev/sddm-astronaut-theme),
and [MPRIS](https://specifications.freedesktop.org/mpris/latest/Player_Interface.html).

## Verification performed

- Hyprbars compiled successfully against the installed 0.56.2 SDK. The native
  VM loaded it without configuration errors. Real pointer clicks minimized,
  maximized, entered fullscreen and closed a floating Alacritty window. The
  existing restore helper returned the minimized window to its workspace.
- The desktop-only patch applied in a disposable diskless Live VM. User and
  system rollback both exited 0; all 9 user and 16 system records matched their
  original contents or correctly removed newly created files.
- All 18 storage tests passed on Arch, including locked/unlocked BitLocker
  discovery, stable Windows aliases, protected encrypted root, mapping merge
  and preservation of custom bookmarks.
- Native QML media flow passed paused seek, selected-player switch, track reset
  and on-demand lyrics. The helper was invoked exactly twice when requested;
  disabled/hidden widgets and embedded lyrics caused no extra online lookups.
- Native drive-dialog flow passed masked input, stdin-only submission and
  immediate field clearing using a synthetic credential and fake backend.
- Hyprlock acquired the real session-lock protocol and rendered Kath in the
  VM with fade capture disabled and a dedicated denying QA PAM service.
  Actual account/password unlocking was not tested. The VM workaround follows
  hyprlock 0.9.6's screencopy requirement for its fade animations.
- Bash syntax, ShellCheck and patch checksum checks passed for the changed
  scripts. No full desktop suite, physical audio test, real encrypted-volume
  unlock, Chrome AUR installation or installed-memory benchmark was repeated.

Screenshots and machine-specific drive maps remain in ignored build output.
The smallest hardware acceptance step is to apply the patch after booting the
installed OS, restart for firmware, then check the detected audio devices and
unlock a data volume read-only using its legitimate credential.
