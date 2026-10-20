# Notifications and background apps

The right panel has two separate controls: the chevron opens a compact grid of
tray icons, and the bell opens Notification center. Both support keyboard focus
and Escape; click outside to close. Tray items show their application name on
hover. Click to activate, middle-click for the app's secondary action, or
right-click for its own menu, including Quit when the app provides it.

Apps must support the standard Linux StatusNotifier tray protocol. Discord can
keep running after its window closes when its own minimize-to-tray setting is
enabled. Forynarch does not intercept every application's Close button or hide
processes that have already exited. Background services without tray icons do
not appear in this grid. Closing a window and quitting an application remain
different operations.

## Notification profiles

Open **Settings → Notifications** or the gear in Notification center.

- **All notifications** shows normal banners.
- **Do Not Disturb** hides all banners, including critical alerts. The moon in
  the panel shows that DND is active. Super+Ctrl+, toggles it.
- **Custom focus** shows only applications in your allowlist, with a separate
  option for critical alerts. Enter the exact application name shown in its
  notification, or allow an app directly from a current notification.

Banner enablement and duration are configurable. Critical alerts remain until
dismissed when allowed. Profiles persist across login. These settings control
desktop banners; an application's own calls, sounds or media are independent.

Notification center shows current messages and up to 50 earlier messages kept
in Mako's memory for this login session. Bodies are displayed as plain text.
Dismiss one message or all current messages. Current messages expose actions
supplied by the sending app. Earlier messages cannot reliably reopen those
actions after the sender withdraws the notification. History is not written to
disk by Forynarch and disappears when Mako or the login session ends.

The small bell dot means a notification arrived since the center was last
opened. It is an unread hint, not a total count of every message still stored.

## Configuration and resource use

Settings: `~/.config/forynarch/notifications.json`. The generated
`notifications.mako` fragment is included before existing user Mako rules;
custom rules are preserved. Edit the JSON or use the UI instead of editing the
generated fragment. Mako remains the only notification daemon. The center polls
only while its UI is loaded; incoming badges use a short IPC callback.

Window previews prepare snapshots for at most three application groups, with
at most three window thumbnails per group. Hidden previews do not stream or
refresh on a timer. Closed applications release their cache; a fourth group
evicts an older one. Snapshot storage is bounded but depends on source-window
resolution: the thumbnail's display size does not limit the compositor's
underlying capture-buffer size. Software rendering uses still frames. Hardware
can refresh visible previews; disable live preview in Panel settings if desired.

Firefox's classic File/Edit/View menu bar is hidden by the
`DisplayMenuBar: never` policy in `/etc/firefox/policies/policies.json`. The
browser's main menu remains available. Maintainers can change this policy;
browser profiles and unrelated policies are preserved.
