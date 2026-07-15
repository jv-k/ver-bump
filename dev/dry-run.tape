# vhs tape — renders a typical `ver-bump --dry-run` as a single PNG.
# Run with: vhs dev/dry-run.tape   (or: pnpm screenshots:dry-run)
#
# Drives dev/sandbox.sh (throwaway repo, seeded commits) with -d so nothing is
# mutated. -q clears the sandbox's own chatter so only ver-bump's output shows;
# -p origin + -d makes the push a previewed no-op (no prompt, no network).
# The single PNG comes from the Screenshot directive at the bottom; the
# animated gif is a throwaway in img/tmp/ (gitignored).

Output img/tmp/dry-run.gif

Set Shell "zsh"
Set FontFamily "JetBrains Mono"
Set FontSize 15
Set Width 1000
Set Height 1000
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
Sleep 200ms
Type "./dev/sandbox.sh -q -v 2.0.0 -d -y -p origin" Enter
Sleep 2500ms
Show
Sleep 600ms
Screenshot img/dry-run.png
