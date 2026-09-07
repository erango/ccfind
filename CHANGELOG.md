# Changelog

## 0.1.0

First release.

- Search the prompts you typed across every Claude Code project directory, then resume the
  session you pick in its original working directory.
- Incremental prompt index under `~/.claude/ccfind-cache`, refreshed by mtime diff: ~5s to
  build, ~0.2s per run after that.
- Colored output with relative timestamps, query highlighting, and wrapped prompt text.
- Browsing shows each session's opening prompt; searching shows the prompt that matched.
- Slash-command prompts render as they were typed instead of as stored XML.
- Detached once-a-day update check with a `brew upgrade` banner.
