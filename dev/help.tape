# vhs tape — renders ver-bump --help as a single PNG (macOS-window look).
# Run with: vhs dev/help.tape   (or: npm run screenshots:help)
#
# vhs emits a full animated GIF for any tape — we don't use it here, so it
# lands in tmp/help.gif (gitignored). The single PNG we care about comes
# from the `Screenshot` directive at the bottom.

Output img/tmp/help.gif

Set Shell "zsh"
Set FontFamily "JetBrains Mono"
Set FontSize 15
Set Width 1900
Set Height 1560
# Monokai Pro palette with a Carbon (#191816) background for the terminal itself.
Set Theme { "background": "#191816", "foreground": "#FCFCFA", "cursor": "#FCFCFA", "black": "#2D2A2E", "red": "#FF6188", "green": "#A9DC76", "yellow": "#FFD866", "blue": "#FC9867", "magenta": "#AB9DF2", "cyan": "#78DCE8", "white": "#FCFCFA", "brightBlack": "#727072", "brightRed": "#FF6188", "brightGreen": "#A9DC76", "brightYellow": "#FFD866", "brightBlue": "#FC9867", "brightMagenta": "#AB9DF2", "brightCyan": "#78DCE8", "brightWhite": "#FCFCFA", "selection": "#5B595C" }
Set Padding 24
Set Margin 20
Set MarginFill ""
Set BorderRadius 10
Set WindowBar Colorful
Set WindowBarSize 40
Set TypingSpeed 40ms

Hide
Type "clear" Enter
Show

Type "./ver-bump.sh --help"
Sleep 400ms
Enter
Sleep 2s

Screenshot img/screenshot.png
