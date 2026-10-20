# Forynarch Kath login theme

Derived from Keyitdev's sddm-astronaut-theme, Hyprland Kath configuration.
Upstream: https://github.com/Keyitdev/sddm-astronaut-theme
Pinned revision: abb3163c724935af888ba5ea9ac0c4f22afd8048
Code license: GPL-3.0-or-later, retained in LICENSE and the upstream headers.
Original theme credit also names Marian Arlt's sddm-sugar-dark.

The Kath background files are the assets shipped at that upstream revision.
Upstream credits https://motionbgs.com and a linked source in its README; asset
and font provenance is not independently established by this preview. Review
redistribution rights before a public release. The existing DejaVu font is used.

Owner-directed changes: visible Shut down / Sleep / Hibernate / Restart controls,
capability checks and confirmation, Forynarch navy/blue palette, a soft horizontal
fade between the local blur and artwork, and a looping Kath video by default.
The owner-supplied MP4 matches the upstream video byte for byte (SHA-256
1ddffbd4d38bc13e9b9f31446fa4cabf102bca1a48291dd542745539ba3fe8c3).
The PNG remains a loading/error fallback. Qt Multimedia and its FFmpeg backend
are runtime dependencies; no developer group is selected by enabling video.
Virtual keyboard loading is disabled by default and needs its Qt runtime if enabled.

## Public build

The public build uses original Forynarch navy artwork from `assets/wallpapers/navy.svg`. Kath video/still files are local optional media, ignored by Git and excluded by the build staging whitelist. Their earlier presence in Git history still requires review before that history is published. The theme code and its GPL notices remain included.
