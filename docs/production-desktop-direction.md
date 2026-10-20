# Desktop implementation direction

Owner request, 15 October 2026. Continue the existing navy/blue identity and
antislop DURING session choice. ENERGY 2 / RHYTHM 2 / MOTION 2.

- Use **File Manager** as the user-facing file manager name. Keep upstream binary,
  package IDs and copyright credits intact. Integrate common file preferences
  into Settings, retaining advanced upstream controls when needed.
- Remove unused Xfce About and network-discovery launchers. Keep required shared
  libraries when another runtime depends on them; do not enable remote access.
- Application choices belong to OS setup, not installed Settings. Live includes
  Firefox and a trial-install helper that needs no typed sudo. Live-only
  authorization must not propagate to installed targets.
  The installed core has no selected browser. Every browser choice is opt-in.
- Arc has no supported native Linux release. FileZilla is a transfer client.
  Show both facts rather than pretending they are ordinary installable browsers.
- Select an account and show a password field only when required. Never infer an
  empty password from a locked account or expose shadow hashes to the greeter.
- Widget editing is an explicit desktop mode with draggable objects, alignment
  grid/snap, presets, Save and Cancel. Normal mode must not intercept clicks on
  empty desktop. Store bounded positions per output and restore on restart;
  clamp layouts when resolution changes. No background animation is needed.

Ship these through the main image/target pipeline. Test UI in the existing VM;
do not relabel unexecuted disk installation paths as production-ready. Real
installation still requires a verified target and its final erase confirmation.
