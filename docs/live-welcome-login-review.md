# Live Welcome and graphical logout

The Live desktop now opens a Welcome offering **Try Forynarch** and
**Install Forynarch**. Try dismisses the Welcome; Install opens the existing
guided setup. Neither choice starts a disk operation. The Welcome is loaded
only on Archiso, once per user runtime, and is destroyed when dismissed.
Installed desktops do not show it.

Both Live and installed sessions use SDDM with the Kath theme. Live previously
started Hyprland from a tty1 Bash autologin, so exiting the compositor returned
to that terminal. Live now includes SDDM and its X server, prepares liveuser
before SDDM starts, and autologins into `hyprland.desktop` only once.
`Relogin=false` leaves the greeter visible after logout. Recovery consoles no
longer start a compositor from `.bash_profile`.

`scripts/configure-login.sh` applies this policy to staged roots. Its target
mode removes Live autologin and Live service dependencies. Both modes use
graphical.target and the existing logind session cleanup policy. SDDM remains
running after logout; user applications belong to the terminated user session.

Version evidence: staged SDDM **0.21.0-7**, Xorg server **21.1.25-1**,
Hyprland **0.56.2**. The session filename and executable were checked in the
installed package. Autologin semantics were checked against the
[SDDM 0.21.0 manual source](https://github.com/sddm/sddm/blob/v0.21.0/data/man/sddm.conf.rst.in).

## Verification

171 native Arch unit/behavior tests pass without skips, including a staged
Live-to-target policy test and rejection of `/` as a staging root. The policy
test verifies graphical boot links, removal of tty startup, Live service
ordering, one-time autologin and removal of Live settings from the target.

R4.1/R4.3 tests reached Welcome, opened setup, logged out to Kath and signed in
again. The exact R4.4 ISO cold-booted to Welcome and returned to the refined Kath
greeter on logout. The current build's results and remaining limits are in
[the R4.4 review](blue-hour-r44-review.md). No physical disk installation was
performed for this fix.
