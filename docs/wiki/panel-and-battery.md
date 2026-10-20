# Panel components and battery power

Open **Settings > Panel** to choose which components appear. Each switch applies
immediately and is saved for your next session. Both Forynarch and MacShell bar
styles use the same selections.

Available components are the applications launcher, running applications,
workspace slots, clock/date, workspace mode label, background apps, notifications,
audio, Control Center, network, battery, Settings, power and Show desktop.
Live window previews have a separate switch. Empty left and right groups disappear.
The workspace mode label remains hidden on narrow screens and in the MacShell bar.
On smaller screens the date and battery percentage shorten to keep groups apart;
clicking still opens full details.

Hiding a button does not stop its service or disable keyboard shortcuts. For
example, Super + Space still opens the launcher. To recover Settings after hiding
its button, search for **Settings** in the launcher, then open **Panel**.

Click the battery indicator to open **Battery & power**. The popup shows each
system battery's charge, charging/discharging status, current power in watts,
remaining time, stored energy, full capacity, health, temperature and charge
cycles when reported by the hardware. **Power settings** opens the full power
page; Escape, clicking outside, or the close button dismisses the popup.

Charging watts measure net power entering the battery. Discharging watts measure
power drawn from the battery. These are not the laptop's total wall consumption
or the charger's rated maximum. Adapter input watts appear separately only when
the adapter reports an actual reading. A configured input limit is never used as
measured consumption.

Missing readings appear as **Not reported**. Remaining time calculated from
current energy/power or charge/current is marked **estimated**. Battery energy
in Wh is displayed only when the driver supplies energy fields; charge in Ah is
not mislabeled as energy. Peripheral batteries, such as a mouse, are excluded.
On machines without a system battery, the bar indicator is hidden and Power
settings explain that no system battery was detected.

The existing shell reads `/sys/class/power_supply` using `forynarch-battery`.
It refreshes every 30 seconds when the indicator is enabled, and every 3 seconds
while the popup or Power settings are open. Hiding the indicator stops its
refreshes when those views are closed. No battery daemon, root access, package
installation, charging-threshold change or power-profile change is required.

Preferences remain in
`~/.local/state/forynarch/appearance.json` (or the corresponding
`XDG_STATE_HOME` directory). The `panelShow...` booleans are validated when loaded;
new components default to visible for older configurations. Source lives in
`PanelComponents.qml`, `DesktopPanel.qml`, `BatteryModel.qml`,
`BatteryDetails.qml`, `BatteryPanel.qml` and `scripts/forynarch-battery.py`.

The conversion and missing-field behavior follow the
[Linux power supply class documentation](https://docs.kernel.org/power/power_supply_class.html).
