# ccfind

Find and resume a Claude Code session, no matter which directory you ran it in.

Claude Code files every session under `~/.claude/projects/<slugified-cwd>/`, and `claude --resume`
only ever offers the sessions belonging to the current directory. So finding *that conversation
about the feature toggle* means first remembering which of your twenty repos you were sitting in.

`ccfind` searches the prompts **you typed**, across every project directory at once, and resumes
the one you pick by `cd`-ing back to where it ran.

```
  ╭─ claude sessions · matching "feature toggle" · showing 4 of 10

   1  ~/git-repos/fred-agent                                 42m ago  16:17
      │ how do I set up the rule for the fred-model feature toggle? I want to
      │ give access to grok to alex@example.com

   2  ~/git-repos/server                                     Sep 03  18:44
      │ Investigate: account does not have this feature toggle enabled, see
      │ the LaunchDarkly flag and tell me which segment it lands in

  resume [1-4] or q >
```

## Install

```sh
brew install erango/tap/ccfind
```

Or drop `bin/ccfind` anywhere on your `PATH`. It needs `jq` and system `perl`.

## Usage

```sh
ccfind <words...>     # search your typed prompts, in every project
ccfind                # list the most recent sessions, in every project
ccfind -n 40 <words>  # cap the number of results (default 20)
ccfind -l <words>     # list only, do not offer to resume
ccfind --reindex      # rebuild the prompt index from scratch
ccfind --version
```

Pick a number and it runs `claude --resume <session-id>` in that session's original directory.

Searching matches on the whole index row, so a folder name works as a query too:
`ccfind fred-agent` finds every session that ran there.

## How it stays fast

Parsing 400MB of JSONL on every search would be unusable, so `ccfind` keeps an index of just
your typed prompts — a few hundred KB — under `~/.claude/ccfind-cache/`:

- `index.tsv` — one row per prompt: log file, timestamp, cwd, session id, text.
- `manifest.tsv` — path and mtime of every session log.

Each run diffs the manifest and re-parses **only** the logs whose mtime changed, carrying the
rest of the index over untouched. In practice that's the one session you have open right now.

| | |
|---|---|
| First run (full build) | ~5s |
| Every run after | ~0.2s |

A couple of details that make the output readable: browsing shows each session's **opening**
prompt (which names the topic, unlike whatever `yes` ended it), while searching shows the prompt
that **matched**; and slash-command prompts, stored as XML, render as `/deploy prod` rather than
`<command-name>/deploy</command-name><command-args>prod</command-args>`.

## Environment

| Variable | Effect |
|---|---|
| `CLAUDE_CONFIG_DIR` | Where Claude Code keeps its data (default `~/.claude`) |
| `CCFIND_NO_UPDATE_CHECK` | Set to anything to disable the update check |
| `NO_COLOR` | Set to anything to disable color |

The update check hits the GitHub releases API at most once a day, fully detached, and reports
from cache — it never adds latency to a search, and never blocks when you're offline.

## Requirements

- bash 3.2+ (stock macOS bash is fine)
- `jq`
- perl 5 with `POSIX` and `Time::Local` (both core; system perl on macOS and Linux works)

## License

MIT
