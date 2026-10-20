# Kath login direction

Owner update: the supplied Kath MP4 is the default looping background. Its
SHA-256 matches the retained upstream video. Keep the PNG as a loading/error
fallback and measure video resource use separately from the static preview.

Use the owner's explicitly selected Hyprland Kath theme from sddm-astronaut-theme,
with the power actions exposed as in Jake the Dog. Retain upstream credits and
keep all user-facing copy English. Antislop DURING is the session selection.

ENERGY 3 / RHYTHM 2 / MOTION 2.

16 October owner update: keep Kath's video and add blue neon and motion.
Use the neon edge to identify the focused credential field or sign-in action.
Power actions stay flat until interaction. Reduce the oversized clock and
pill controls so artwork, credentials and supporting actions have distinct
weight. A short horizontal form arrival and 140–160 ms interaction responses
provide motion without extra looping particle effects or blur surfaces.

- Keep the Kath artwork and familiar left-side clock, account fields and session
  choice. Use Forynarch's existing navy and pale blue for a consistent transition.
- Blend the edge of the local blur and tint over a bounded fade band, rather than
  separating the form and artwork with a sharp vertical rectangle.
- Loop the owner-selected Kath video, with a short form arrival and local blur.
  Keep a static fallback; measure the greeter separately from desktop idle
  memory after login.
- Show all four power actions. Unsupported actions stay disabled with an explanation;
  never force hibernation availability or bypass SDDM/logind capability checks.
- Power actions require an explicit confirmation. Preview tests use inert models
  and must never suspend or shut down the actual test machine.
- Keep passwords handled by SDDM's authentication path. Do not log credentials,
  automatically log in installed users or change real accounts in a visual task.
- Test visual bounds, keyboard focus, masking and failed authentication in a greeter
  preview. Real PAM login, resume and installed idle memory need separate acceptance.
