# vhs tape — renders img/social-preview.png, the 1280x640 card for GitHub's
# repo Settings > Social preview. Same theme/font as the README stills.
# Run with: vhs dev/social.tape   (the throwaway gif lands in img/tmp/)

Output img/tmp/social.gif

Set Shell "zsh"
Set FontFamily "JetBrains Mono"
Set FontSize 32
Set Width 1280
Set Height 640
# Monokai Pro palette with a Carbon (#191816) background — matches demo.tape.
Set Theme { "background": "#191816", "foreground": "#FCFCFA", "cursor": "#191816", "black": "#2D2A2E", "red": "#FF6188", "green": "#A9DC76", "yellow": "#FFD866", "blue": "#FC9867", "magenta": "#AB9DF2", "cyan": "#78DCE8", "white": "#FCFCFA", "brightBlack": "#727072", "brightRed": "#FF6188", "brightGreen": "#A9DC76", "brightYellow": "#FFD866", "brightBlue": "#FC9867", "brightMagenta": "#AB9DF2", "brightCyan": "#78DCE8", "brightWhite": "#FCFCFA", "selection": "#5B595C" }
Set Padding 24
Set Margin 0
Set BorderRadius 0
Set WindowBar Colorful
Set WindowBarSize 40
Set CursorBlink false

Hide
Type "clear && ./dev/social-frame.sh && sleep 60" Enter
Sleep 2s
Show
Sleep 2s
Screenshot img/social-preview.png
Sleep 500ms
