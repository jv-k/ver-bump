# vhs tape — records a realistic ver-bump run against a throwaway sandbox repo.
# Run with: vhs dev/demo.tape   (or: npm run screenshots:demo)
#
# Uses dev/sandbox.sh, which seeds a temp git repo with conventional commits
# and forwards extra flags to ver-bump. -y skips interactive prompts so the
# recording is deterministic. The sandbox invocation itself is kept off-screen
# (Hide/Show) so the viewer only sees ver-bump's output.

Output img/demo.gif

Set Shell "zsh"
Set FontFamily "JetBrains Mono"
Set FontSize 15
Set Width 1000
Set Height 1200
# Monokai Pro palette with a Carbon (#191816) background for the terminal itself.
Set Theme { "background": "#191816", "foreground": "#FCFCFA", "cursor": "#FCFCFA", "black": "#2D2A2E", "red": "#FF6188", "green": "#A9DC76", "yellow": "#FFD866", "blue": "#FC9867", "magenta": "#AB9DF2", "cyan": "#78DCE8", "white": "#FCFCFA", "brightBlack": "#727072", "brightRed": "#FF6188", "brightGreen": "#A9DC76", "brightYellow": "#FFD866", "brightBlue": "#FC9867", "brightMagenta": "#AB9DF2", "brightCyan": "#78DCE8", "brightWhite": "#FCFCFA", "selection": "#5B595C" }
Set Padding 24
Set Margin 20
Set MarginFill ""
Set BorderRadius 10
Set WindowBar Colorful
Set WindowBarSize 40
Set TypingSpeed 45ms
Set PlaybackSpeed 1.0

# Boot the sandbox off-camera — we only want the ver-bump output on screen.
Hide
Type "clear" Enter
Sleep 300ms
Type "./dev/sandbox.sh -q --remote -v 2.0.0 -y -p origin"
Enter
Sleep 250ms
Show

Sleep 10s
