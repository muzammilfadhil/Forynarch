# Search, widget controls and motion

## Intent and source

Address the user's three concrete complaints: the old search UI, uneven
shortcut alignment, and desktop widgets that could only be hidden together.
Add restrained motion and real transition blur while preserving the below-3-GB
idle limit and the English-only interface.

Source changes are in config/quickshell/forynarch, scripts/forynarch-launcher.sh,
the shader compiler/start/session/preview helpers, the pipeline and its versioned
Hyprland adapter. Two launcher routing tests were added; the adapter test now
expects the launcher helper. No optional developer group was enabled and no
new runtime package was installed for this iteration.

## Implemented behavior

- An original Quickshell launcher with a large search field, installed-app
  icons/descriptions, Files/Terminal/Settings quick actions, ranked results,
  empty state, scrolling and Up/Down/Enter/Escape navigation. Exact and prefix
  name matches precede description/keyword matches. Hidden entries are ignored.
- Super+Space and the panel launcher use the same helper. Fuzzel remains a
  fallback when shell IPC is unavailable; power/confirmation menus retain their
  existing behavior. The Live Lua variable replacement handles the spacing in
  the actual packaged configuration rather than assuming one space around '='.
- App execution uses parsed desktop-entry argument arrays and working directory.
  Terminal entries are wrapped with Foot. Search text is never evaluated as a
  shell command. File and command search remain future vision features.
- Shortcut rows have a shared Action/Shortcut column boundary, identical 48px
  row heights and consistent keycaps. All eight rows fit the tested viewport.
- Separate Clock, Calendar, Greeting and Music switches. Disabled widgets unload
  their components and the column closes gaps. A master visibility switch keeps
  individual choices intact; all four disabled also unloads the layer window.
- Widget order can change using Up/Down controls. Left/Right column placement
  and Small/Medium/Large size presets persist. Size automatically fits the
  available vertical space. This is column-based customization; arbitrary
  individual dragging, resizing and third-party widget plugins are not supplied.
- Popovers enter in 180ms and exit in 150ms through fade, 3% scale and 16px
  translation. The closing tree remains loaded for 180ms so exit motion can
  finish. Switching popovers releases the previous keyboard grab immediately.
- A real nine-tap GLSL directional motion-blur shader samples the UI's rendered
  layer during those transitions. The layer and shader pass turn off once the
  animation stops. This is shell-surface motion blur, not application/window
  motion-vector reconstruction. Native Hyprland window animation is enabled
  separately through its existing packaged curves when motion is enabled.
- Reduced motion disables those transitions, hover color easing, widget reflow
  and native compositor animation. Motion blur has its own switch. There is no
  perpetual frame animation or animated wallpaper; the clock stays minute-based.

All new settings are type-checked on load and saved with the existing atomic
appearance JSON. The widget order must contain each known widget exactly once;
unknown widget keys and unsupported size presets are ignored.

## Versions and executed checks

Hyprland 0.56.2-4, Quickshell 0.3.2-1 and Qt/qsb 6.12.0 were checked in the
existing Fornarch Live VM. Both shader bundles compiled for GLSL 100 ES/120/150,
HLSL 50 and MSL 12. Only software OpenGL was executed. Bundles remain generated,
ignored output; the glass profile builds and installs both bundles.

- Windows: 48 unit tests pass, Bash syntax checks and pipeline plan exit 0.
- Arch Live: 48 tests pass in 0.225s; official portable ShellCheck 0.11.0 exits 0.
- QML loads and Hyprland configerrors is empty. Nonfatal Qt Wayland focus
  warnings on some popup transitions remain.
- Appearance and Desktop scroll content now explicitly follows the loaded
page's implicit height. Mouse-wheel scrolling reaches the lower controls;
changing pages resets the scroll position. Actual mouse clicks on Reduced
motion set motion=false, and on Motion blur set motionBlur=false. Both were
restored afterward. All eight shortcut rows remain visible at 1280×800.
- Super+Space opens the new launcher. Typing 'foot' yields Foot, Foot Client and
  Foot Server, with Foot ranked first. Down selects index 1; Up returns to 0.
  Typing 'zzzNoSuchApp' produces zero matches. Enter opens a new Foot window;
  only that test window was closed afterwards, preserving existing user apps.
- Idle launcher IPC reports animating=false and blurActive=false. A rendered
  intermediate popup frame demonstrates real directional blur. Reduced motion
  reports both false immediately on opening. Smooth frame pacing is not proven
  by these checks, particularly with the VirtualBox software renderer.
- Real mouse input disables Calendar while other cards remain and reflow. All
  four widgets disabled reports widgetsLoaded=false. Real mouse input on Clock's
  Down button changes the order to Calendar/Clock/Greeting/Music.
- A full shell restart retains Clock+Music only, 80% size, Right placement and
  Clock/Music/Calendar/Greeting order. The preview was then restored to all four
  cards, Medium, Left and the original order with motion/blur enabled.
- Runtime captures, source transfer archives and RAM logs stay under ignored
  out/virtualbox. They are not release artifacts or source commits.

## Memory and remaining gates

Six samples at nominal five-second intervals read MemTotal minus MemAvailable
for the entire Linux guest, including retained user apps and Live development
processes. The limit is 3,000,000,000 bytes, and swap use is recorded:

| State | Peak bytes | GB decimal | Swap | Exit |
|---|---:|---:|---:|---:|
| Motion enabled, desktop after closing settings | 1,516,306,432 | 1.516 | 0 | 0 |
| Motion enabled, launcher open | 1,550,446,592 | 1.550 | 0 | 0 |

Raw records: out/virtualbox/motion-idle-memory.txt and
out/virtualbox/motion-search-memory.txt. The launcher record also confirms its
animation and motion-blur layer are inactive after the transition.

The initial post-close sample includes transient/cache effects. These short
development checks do not establish an installed-target cold-boot baseline or
certify the three-boot, 10-minute acceptance gate.

The existing ISO does not contain this work. Builder SSH recovery and the glass
ISO build/boot remain pending. Hardware tests still need physical GPU rendering,
frame pacing, battery use, fractional scaling, multiple monitors, active media
players and a prolonged popup/widget leak test. Next: recover builder access,
build the updated glass profile, and verify a fresh Live boot plus independent
installed target rather than treating this RAM-resident preview as a release.

Official references checked:

[Qt ScrollView sizing](https://doc.qt.io/qt-6/qml-qtquick-controls-scrollview.html#sizing)
and [Loader sizing](https://doc.qt.io/qt-6/qml-qtquick-loader.html#loader-sizing-behavior)
guided the settings scrolling fix.
[Desktop entries](https://quickshell.org/docs/v0.3.0/types/Quickshell/DesktopEntry/),
[Qt item layers](https://doc.qt.io/qt-6/qml-qtquick-item.html#layer.effect-prop),
[ShaderEffect](https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html), and
[Hyprland animations](https://wiki.hypr.land/configuring/core/animations/).
