# Kath login: blue neon refinement

The 16 October owner direction keeps the original Kath video and requests neon
and motion. The form now uses a smaller light-weight clock, 336 px credential
fields, 48 px controls and flat supporting power actions. The active field or
sign-in button receives an ice-blue edge and bounded glow. Its small texture is
allocated only during focus/hover; there is no full-screen glow pass or particle
service. Existing local video blur and the gradual form-to-artwork blend remain.

The form enters horizontally over 440 ms with a 380 ms opacity transition.
Control feedback lasts 120–160 ms. `ReduceMotion="true"` removes these transitions;
the Kath video is not loaded in this mode or when `PauseBackground="true"`.
The existing PNG becomes the static fallback, reducing decoding work and RAM.
The video is still the owner-selected MP4; no replacement artwork was generated.

Passwordless accounts initially focus Sign in. Other accounts retain the password
field. Editing an account name must not move keyboard focus during typing.
Authentication stays in SDDM/PAM. All four power controls remain available for
inspection; unavailable hibernate is disabled and explained. Power actions still
require confirmation with Cancel initially focused.

Native QA uses Arch SDDM 0.21.0-7 and Qt 6.12 on a separate VirtualBox Live VM.
The real greeter rendered the new layout, video and restart confirmation. The
inert power harness passed action mappings, capability rechecks, cancellation and
modal focus. Real passwordless sign-in using Enter passed. Switching to an unknown
account name displayed the password field without interrupting username typing.
Reduced motion produced identical consecutive screenshots and the new greeter
did not load Qt Multimedia; its RSS snapshot was 134,704 kB. Plymouth had exited.
These are separate from the installed desktop RAM measurement. The executed
greeter resolution is 1280 × 800; smaller screens and physical GPU video decoding
still need their own checks.

Upstream credits and GPLv3+ notices remain in the theme. See
[the design direction](../config/sddm/themes/forynarch-kath/DESIGN.md) and
[upstream provenance](../config/sddm/themes/forynarch-kath/UPSTREAM.md).
