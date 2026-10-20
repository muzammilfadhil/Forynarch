# Auto-snap report: VirtualBox viewport clipping

## Intent and scope

Investigate the reported lower-screen overflow in the running R47 Live VM.
The change is a reversible VirtualBox frontend preference, not a compositor
geometry patch. Existing user windows and the running session were preserved.

## Evidence

Hyprland 0.56.2 reported a 1280 x 800 monitor at scale 1, with reserved space
`[0, 64, 0, 0]`. The two terminal windows were native tiles:

| Window | Position | Size | Bottom edge |
| --- | --- | --- | --- |
| Left | 15, 79 | 618 x 706 | 785 |
| Right | 647, 79 | 618 x 706 | 785 |

Both were inside the guest monitor. The submitted host screenshot showed a
shorter VirtualBox viewport and a vertical scrollbar, hiding the bottom of the
800-pixel guest display. These were tiled windows, not floating region snaps.

## Change and verification

Set `GUI/ScaleFactor` to `0.95` on the running review VM. The 800-pixel guest
display now occupies 760 host pixels vertically. A host-window screenshot
confirmed both lower window borders are fully visible and the scrollbar is
gone. Guest geometry remained unchanged. No application was closed, no session
restarted, and no Linux packages or background services were added.

This VM has `virtualbox-guest-utils-nox` 7.2.20-1 and no VBoxDRMClient; automatic
guest resizing must not be assumed available. Scaling the frontend avoids
depending on a guest display-resize service. The 95% preference persists for
this VM; it does not belong in the shipped Linux monitor configuration.

Restore the original frontend scale with the VM's View menu or by removing the
`GUI/ScaleFactor` extra-data preference. A substantially smaller host window
can require a different scale or VirtualBox Scaled Mode.

## Limits

This verifies the submitted viewport-clipping case, not every floating-snap,
application minimum-size, fractional-scale or multi-monitor scenario. The
default snap preview's 64-pixel panel allowance matched this monitor's actual
reservation, so it was not changed. No OS code changed and no ISO rebuild was
needed for this correction.

## Sources

- [Oracle VirtualBox display and scaled mode](https://docs.oracle.com/en/virtualization/virtualbox/7.1/user/Introduction.html)
- [VirtualBox frontend scale preference implementation](https://github.com/mirror/vbox/blob/master/src/VBox/Frontends/VirtualBox/src/extradata/UIExtraDataManager.cpp)
