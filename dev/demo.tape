# vhs tape — records a realistic VerBump run against a throwaway sandbox repo.
# Run with: vhs dev/demo.tape   (or: pnpm screenshots:demo)
#
# dev/sandbox.sh --setup-only scaffolds a temp repo (with a bare 'origin' via
# --remote) and prints its path; we cd in and drive the REAL VerBump through a
# thin `VerBump` function so the recording shows a clean `VerBump …` command
# rather than the dev scaffolding. No -p and no -y, so VerBump asks before
# pushing — we answer 'y' to push to the throwaway origin and finish on DONE.
# Both temp dirs are removed off-camera at the end. The finished DONE frame is
# also saved as a still (img/demo-final.png) via the Screenshot directive.

Output img/demo.gif

Set Shell "zsh"
Set FontFamily "JetBrains Mono"
Set FontSize 15
Set Width 1000
Set Height 900
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

# Scaffold the sandbox off-camera and expose a clean `VerBump` command that
# runs the real script from inside the throwaway repo.
Hide
Type "clear" Enter
Sleep 300ms
Type `VB="$PWD/VerBump.sh"` Enter
Type `VerBump() { "$VB" "$@"; }` Enter
Type `set -- $(./dev/sandbox.sh --setup-only --remote); SBX="$1"; RMT="$2"` Enter
Type `cd "$SBX"` Enter
Type "clear" Enter
Show

# The demo: bump to 2.0.0, answer the push prompt, land on DONE.
Type "VerBump -v 2.0.0"
Sleep 600ms
Enter
Sleep 4s
Type "y"
Sleep 400ms
Enter
# Sizeable pause holding the finished DONE frame so it reads comfortably next to
# the usage section, then save that frame as a standalone still. The trailing
# Sleep keeps the clean DONE frame on screen while the Screenshot flushes.
Sleep 8s
Screenshot img/demo-final.png
Sleep 1s

# Tear down the throwaway repos off-camera. Give Hide a beat to fully engage
# before typing, so the teardown keystrokes never bleed into the last frame.
Hide
Sleep 500ms
Type `cd "$(dirname "$VB")"` Enter
Type `rm -rf "$SBX" "$RMT"` Enter
