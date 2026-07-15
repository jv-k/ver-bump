# vhs tape — renders `ver-bump --completions zsh` (a snippet) as a single PNG.
# Run with: vhs dev/completions.tape   (or: pnpm screenshots:completions)

Output img/tmp/completions.gif

Set Shell "zsh"
Set FontFamily "JetBrains Mono"
Set FontSize 15
Set Width 1000
Set Height 900
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
Type "./ver-bump.sh --completions zsh | head -28"
Sleep 400ms
Enter
Sleep 1500ms
Screenshot img/completions.png
