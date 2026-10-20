# Widgets and emoji

Open **Settings → Desktop → Edit widget layout**. Choose an Essentials, Focus,
Laptop or Minimal pack, then enable individual widgets as needed. Drag widgets
to arrange them. **Snap to grid** aligns their positions; **Show grid** displays
the guide. Left, Right and Balanced offer placement presets. Smaller and Larger
adjust the layout scale. **Save layout** keeps the changes; **Cancel** or Escape
restores the previous layout. Positions are stored separately for each output.

Available widgets are Analog clock, This week, Greeting, Music, Digital clock,
Focus timer, Memory, Battery, Quick launch and Keyboard guide. Extra widgets
start disabled. The music spectrum appears while a compatible MPRIS player is
playing; reduced motion disables the spectrum process.

Press **Super + .** to open the emoji picker. Search by English name or browse
categories, choose a skin tone and select an emoji. Recent selections remain
available offline. Symbols and kaomoji are also included. Selection copies the
text and can paste it into the application that had focus. If that application
or monitor changes during selection, paste manually from the clipboard.

The GIPHY tab accepts a personal API key through its settings control. The key
is stored in a private user configuration, can be changed or cleared, and is
sent only for requested searches. Internet access is required. Select a result
to copy its link; inserting a binary GIF depends on the receiving application
and is not implemented by this picker.

Noto Color Emoji is included. If a licensed Apple Color Emoji font is already
installed locally, the picker can use it; Forynarch does not supply Apple's
font file. Font discovery follows fontconfig, including the usual user font
directory `~/.local/share/fonts`. Run `fc-cache -f` after adding a licensed font,
then reopen the picker. Its font choice is saved with the other picker settings.

The picker also has **Install emoji font…**. Choose a local TTF, OTF or TTC
file that you have permission to use. The font is validated with fontconfig,
copied into `~/.local/share/fonts/forynarch-emoji`, selected immediately, and
preferred for the generic `emoji` font family in the user's fontconfig settings.
The chosen file is loaded directly by Qt so it can be used without restarting
the desktop. Other applications may need reopening before discovering the font.
No sudo or download is involved. Apple's font assets are not bundled: the
[conversion project's documentation](https://github.com/samuelngs/apple-emoji-ttf)
also distinguishes its MIT scripts from Apple's font assets. Glyph appearance
inside a receiving application depends on that application's font selection.
