# Installer UI review

Historical first revision. The owner's subsequent screenshot-directed shader
revision is documented in [installer reference style](installer-reference-style.md),
including its updated design direction, native tests and Live measurements.

15 October 2026. Scope: the standalone installation **setup/review preview**.
This report does not approve partition execution or an installable OS release.
Antislop 3.2.20, during mode, selected explicitly by the owner for this session.

Intent: remove the generic card-heavy wizard, keep the owner's navy/blue identity,
and make the real setup decisions readable and usable with a keyboard.
Affected source: `config/quickshell/forynarch-installer/`, the separate Live
launcher/metadata helpers, installer integration and read-only review tests.
The [design direction](../config/quickshell/forynarch-installer/DESIGN.md) records
ENERGY 2 / RHYTHM 2 / MOTION 2 and the reasons for layout, palette and motion.

## Executed checks

- Arch Live: **101 Python tests, 1.702s, OK**, no skips.
- Windows Check: **101 total, 53 passed, 48 Linux-only skips, 1.984s, exit 0**.
- Native QML flow: exit 0. All nine real page components load; account validation,
  secret isolation/clearing, offline reset, optional-software and matching-driver
  checkbox clicks, malformed inventory/Retry recovery, empty storage, equal account
  column widths, non-executable review and modal keyboard focus pass.
- Builder ShellCheck 0.11.0: no findings, exit 0, including both native QML runners.
- Fifteen foreground/background contrast pairs calculated with the WCAG relative
  luminance formula: **5.47:1 minimum**, selected field text. Inactive rail text:
  5.88:1; body text: 9.08:1; primary action: 9.42:1. The wallpaper is confined to
  Welcome artwork; form text uses solid backgrounds.
- Real VM window verified at **880 x 620** and the current **1280 x 800** display.
  A clipped rail footer was fixed using an independently scrollable stage list;
  the Welcome artwork contracts at the smaller size. Form content scrolls while
  Back/Continue remain outside the scroll area.
- Six post-close Live samples peaked at **1,915,813,888 bytes**, swap **0**,
  using MemTotal minus MemAvailable; collector exit 0. Temporary source/package
  files remain in RAM. This is not the installed-core memory acceptance test.

Runtime: Quickshell 0.3.2-1, Qt 6.12, Hyprland 0.56.2-4. `fc-match sans`
resolves to the installed DejaVu Sans. No packages were installed for this UI
revision. Native logs show no QML errors; existing Qt Wayland text-input focus
warnings remain. The source and current disposable Live preview were updated;
the ISO was not rebuilt.

## Recorded interaction evidence

| Control | Result |
| --- | --- |
| Begin setup and Continue | Native mouse navigation reached all nine stages; invalid account/target choices block Continue. |
| Offline/download radio rows | Native click changed `offline`; no download starts. Offline reset removes extra selections in the native regression. |
| Network settings | Native click opened the real Network Settings page; closing it preserved installer state. Live NetworkManager is inactive and no Wi-Fi adapter is attached; no connectivity change was attempted. |
| Timezone search/dropdown | Native typing and arrow/Enter selection chose Asia/Jakarta; Review showed that exact timezone. |
| Keyboard selection/test field | The real page and bounded XKB model load; current-Live-layout limitation is visible. No Live keyboard layout is changed. |
| Disk dropdown/radio choices | Native dropdown selected the VM disk and entire-disk planning; Review showed the disk path and data-loss description. All three choices have real state handlers and require review. |
| Name/username/computer/password fields | Native typing with Tab traversal populated synthetic QA data; passwords were masked and Continue became enabled only for valid matching entries. |
| Password visibility | Real Qt control clicks toggle show/hide in the isolated QML regression. |
| Optional software | Every catalog checkbox was clicked on/off through Qt's native click method; selected group state followed each click. Native mouse Git selection produced `Optional package plan: git` in Review. No package install occurs. |
| Matching driver selections | Isolated synthetic Intel and AMD adapters: each offered checkbox clicked on/off and updated selected driver IDs. Vendor filtering and unsupported NVIDIA rejection have backend tests. This is not physical GPU acceptance. |
| Reduce motion | Real Qt checkbox click changes the flag controlling the finite page-fade duration. No looping animation is used. |
| Previous-stage navigation/Back | Native Welcome navigation returned from Connection without resetting choices; Back is a real decrement action and retains fields in the native regression. |
| Inventory error/Retry | Malformed test-process output showed an error, blocked Continue and exposed Retry; clicking Retry recovered real inventory. |
| Empty storage | Native regression supplied an empty inventory; target stayed null, Continue stayed blocked and clicking Detect disks again restored real inventory. |
| Review/refresh | Real review helper resolved package choices and returned blockers with `canExecute:false`; native Refresh click repeated read-only discovery. |
| Cancel/Keep setting up/Escape | Native Escape opened the modal; Escape or Keep closed it. The native regression verifies the dialog owns keyboard focus. |
| Leave setup with keyboard | An Enter activation defect was found and fixed. Native Escape, Tab, Enter subsequently exited the installer; its IPC instance was absent. Synthetic credentials were not retained. |
| Install unavailable | Explicitly disabled, with a source TODO and visible Welcome/Review limitation. No fake install progress, completion or reboot action. |

## Antislop delivery gate

PASS below applies to this bounded preview UI and its honest unavailable states.
Rules requiring real installation remain outside this UI delivery and are listed
in [standalone-installer.md](standalone-installer.md).

| Gate item | Status and evidence |
| --- | --- |
| R-02, copy punctuation | PASS: no em-dash character in the installer QML/JS source. |
| R-03, bounds | PASS: native 880 x 620 and current VM display inspected; scrollable content and fixed actions. No mobile variant is shipped. |
| R-17, numbers | PASS: disk sizes/timezones/hardware come from inventory; step count comes from the real nine-stage model. No invented metrics. |
| R-18, testimonials | PASS: none included. |
| R-23, assets/navigation | PASS: existing approved wallpaper, text wordmark and the requested welcome/account/driver flow; no new logo, avatar or illustration. |
| R-24, destinations | PASS: all nine page components instantiate; previous-stage and network actions have real destinations. |
| R-25, contrast | PASS: fifteen calculated pairs, minimum 5.47:1; solid form surfaces. |
| R-26, actions | PASS: recorded handlers and native interactions above; unavailable installation is visibly disabled and has a TODO. |
| R-27, states | PASS: loading message, empty storage, error and working Retry; malformed-output recovery executed natively. |
| R-28, FAQ | PASS: no FAQ. |
| R-32, keyboard | PASS: native Tab typing and modal Escape/Tab/Enter exit; radio keys and visible focus indicators; Enter activation regression corrected. |
| R-33, source | PASS: revised UI authored directly in QML. Build integration copies those files; test injection modifies an isolated fixture only. |
| R-34, themes | PASS: one owner-requested navy theme; no incomplete light/dark toggle. |
| R-35, execution | PASS: native application, full page regression and the recorded interaction checks above; code-only limitations are explicitly identified. |
| R-36, claims | PASS: preview/executor limits and hardware-test limits are explicit; no security or performance marketing claims. |
| R-37, direction | PASS: owner direction and scoped DESIGN.md precede the revision. |
| R-38, content | PASS: real catalogs/inventory; synthetic QA data stays in tests and was discarded. |
| R-01, gradients | PASS: only the existing OS wallpaper artwork uses its approved gradients; controls have solid fills. |
| R-04, icons | PASS: radio state, check marks and dropdown chevrons communicate actual controls; no decorative feature icons. |
| R-06, typography | PASS: installed DejaVu Sans for readable forms; no wide-tracked labels or terminal styling. |
| R-07, background | PASS: plain navy work surface and the existing OS wallpaper; no grid or blueprint. |
| R-08, arrows | PASS: only functional dropdown indicators; action buttons have no decorative arrows. |
| R-09, badges | PASS: preview status is plain text; no promotional capsule badges. |
| R-10, glass | PASS: installer content uses solid surfaces; existing desktop glass preferences are preserved. |
| R-12, shadows | PASS: no card/button shadow stack. |
| R-13, glow | PASS: no glow. |
| R-14, cards | PASS: functional radio rows and conventional forms replace repeated feature cards. |
| R-19, animation | PASS: finite 140 ms page transition with Reduce motion; no bounce, parallax or idle animation. |
| R-22, illustration | PASS: existing Forynarch wallpaper, no stock blob or generated illustration. |
| Dials declared | PASS: ENERGY 2 / RHYTHM 2 / MOTION 2 in DESIGN.md. |
| Dials reflected | PASS: open Welcome composition, bounded forms/radio rows and restrained finite motion. |
| Focal points | PASS: product wordmark on Welcome, decision heading on forms, chosen configuration on Review. |
| Structural whitespace | PASS: bounded form width, grouped field rows and persistent action region. |
| Deliberate accent | PASS: pale blue marks the primary action and selected state; warnings use peach. |
| Identity motif | PASS: navy palette and the existing folded-blue wallpaper connect the app to the OS. |
| Design Read | PASS: owner brand/flow requirements and explicit dials recorded before this revision. |
| C-1, intentionality | PASS: layout, type, palette, spacing and motion reasons are in DESIGN.md. |
| C-2, completeness | PASS: setup/review actions work; unavailable execution is clearly labeled. No installability claim. |
| C-3, content | PASS: each stage serves an actual installation decision. No marketing filler sections. |
| C-4, resilience | PASS: small-window bounds, account validation, inventory retry, empty state and keyboard cancellation checked. |
| C-5, evidence | PASS: observations and preview boundaries are separated from future installation acceptance. |
| R-05, composition | PASS: real installation sequence with distinct Welcome, form, radio and Review structures. |
| R-11, radii | PASS: 5 px fields, 6 px buttons, flat radio rows and a 10 px modal. |
| R-15, CTAs | PASS: Begin setup, Continue, Back, Retry and Leave setup name real actions. |
| R-16, copy | PASS: concrete setup instructions; no AI marketing vocabulary. |
| R-20, identity | PASS: approved OS wallpaper, navy identity and Forynarch-specific core/software policy. |
| R-21, dark theme | PASS: navy/dark-first is an explicit project requirement. |
| R-29, palette | PASS: navy surfaces, pale blue action/selection accent, peach limitations and neutral text. |
| R-30, copying | PASS: no cloned commercial product layout; the OS's own wallpaper is reused. |
| R-31, reasons | PASS: each major decision is documented in the scoped design file. |

## Remaining work

Installation execution, account/password transport and authoritative account
creation, exact GPU checks, manual layouts/encryption, real network/payload
verification, progress/recovery and boot acceptance remain pending. Next smallest
step: validate a versioned installation backend and its read-only plan contract
before authorizing a disposable UEFI test disk. Physical GPU/network and installed
idle-RAM tests remain separate. No disk writes or ISO rebuild occurred here.
