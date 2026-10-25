# bm

bm keeps all your bookmarks in one browser-independent JSON file, merges Chromium-family browsers and Safari into it, files new bookmarks into your existing folders, and writes them back out or exports them as HTML, CSV or TOON.

Real output on the generic sample in `docs/sample/Bookmarks` (reproduce: `BM_DB=/tmp/s.json bm pull file --path docs/sample/Bookmarks`, move two bookmarks into `bookmark_bar/Inbox` with `bm mv`, then run the commands below):

```
$ bm pull file --path docs/sample/Bookmarks
9 new, 0 already known

$ bm tree --depth 2
bookmark_bar (9)
  Cooking (2)
  Dev (5)
  Inbox (2)

$ bm classify
  ok 498	bookmark_bar/Dev/Rust	serde and tokio async tutorial	https://example.com/tokio-serde-async
  ok 4200	bookmark_bar/Cooking	Weeknight pasta ideas	https://food.example/pasta-night

$ bm ls --host docs.rs
folder                 title                url
bookmark_bar/Dev/Rust  tokio async runtime  https://docs.rs/tokio/

$ bm export --format toon --fields title,url --limit 3
bookmarks[3]{title,url}:
  The Rust Book,"https://doc.rust-lang.org/book/"
  tokio async runtime,"https://docs.rs/tokio/"
  serde documentation,"https://serde.rs/"
```

## Install

Requires Bend 2 (developed with v2.0.38) and the `bend-kit-json`, `bend-kit-bytes`, `bend-kit-files` and `bend-kit-process` packages from <https://github.com/paymog/bend-kit>, imported by the source.

```
git clone https://github.com/davidawad/bm && cd bm
bend main.bend -o bm        # or just run bin/bm, which builds into ~/.cache/bm on first use and after any .bend change
```

## Usage

```
bm pull helium            # merge Helium's bookmarks into the DB (new URLs only; the DB wins)
bm tree --depth 2         # folders with counts
bm classify               # suggest a folder for every bookmark in bookmark_bar/Inbox
bm classify --apply       # ... and move the confident ones
bm classify --llm "claude -p --model claude-haiku-5-5 --no-session-persistence"
bm push helium            # regenerate Helium's Bookmarks file (close the browser first; a .bm-backup copy is kept)
bm export-html --out b.html   # Netscape HTML: Safari, Firefox and every other browser import it
```

The DB is one JSON file, one bookmark per line, at `~/.local/share/bm/bm.json` by default (`bin/bm` creates the directory). `BM_DB` or `--db` overrides the path. To seed it from an existing Chromium file: `bm pull file --path /path/to/Bookmarks`.

## Status and limitations

- Safari push is intentionally unsupported: its bookmarks carry iCloud sync records that a regenerated file would drop. Use `bm export-html` and Safari's File > Import.
- TOON output is verified only against the spec examples.
- Classifier accuracy is modest without `--llm`: on the author's 3,100 bookmarks, `bm eval --every 10 --depth 2` gave about 55% at two levels and about 18% at exact leaf folders. Treat it as a first pass.
- Requires Bend 2 (v2.0.38) and the bend-kit packages above. Only tested on macOS.

## Querying and export

```
bm ls --folder bookmark_bar/Engineering --host github.com --since 2025-01-01      # table (folder, title, url)
bm ls --text tokio --format urls                                                  # one URL per line
bm export --format toon --fields title,url,date --limit 50                        # json by default; toon, csv, tsv, jsonl, md, html
bm count --by host --limit 10                                                     # group: folder host root year month depth
bm stats                                                                          # totals, inbox, duplicate URLs, date range
bm ls --dupes --fields folder,url                                                 # URLs filed in more than one folder
```

Filters: `--folder PATH` (the folder and everything under it), `--host H` (H and its subdomains), `--text T`, `--since` and
`--until` (YYYY-MM-DD), `--dupes`. Shaping: `--sort FIELD`, `--reverse`, `--limit N`, `--fields a,b`, `--out FILE`.
Fields: folder, title, url, added (browser timestamp), date (ISO 8601), host, root, year, month, depth. Formats follow
RFC 4180 (csv) and TOON v3 (tabular arrays, quoting per its section 7). `bm ls` prints an aligned table, `bm export` prints
json, and `--format` overrides either.

## Behavior

- **Hierarchy.** A bookmark's `folder` is a `/`-joined path starting at a browser root: `bookmark_bar`, `other`, `synced`.
  `push` rebuilds the nested folder tree from those paths. Folders come out in sorted order; bookmarks keep DB order.
- **Merge.** The DB wins. A URL already in the DB (compared after normalizing: lowercase host, no fragment, no `utm_*`/`fbclid`/
  `gclid`, no trailing slash) is skipped, never moved, retitled or deleted. A pull never deletes; only `bm rm` does.
  The first pull into an empty DB keeps every folder as-is (and keeps one copy of a URL per folder). Later pulls put new
  bookmarks that sit directly in a browser root into `bookmark_bar/Inbox`.
- **Browsers.** chrome, helium, brave, edge, browseros (all Chromium `Bookmarks` JSON, pull and push), safari (pull only),
  or `file --path P`. Safari's file needs Full Disk Access for the terminal; pull reads it through `plutil -convert xml1`.
  Pushing into Safari's live file is left out on purpose: its bookmarks carry iCloud sync records that a regenerated
  file would drop. Use `export-html` and Safari's File > Import.
- **Classifier.** Every filed bookmark votes for its folder with title words, URL words and its host. A new bookmark scores
  each folder (rare tokens and small folders weigh more), the scores roll up to ancestor paths, and the pick walks down
  from the root while one child holds enough of the score. `bm eval --every 10 --depth 2` holds out every 10th bookmark and
  reports right/wrong: on the author's 3,100 bookmarks that is about 55% at two levels and about 18% at exact leaf
  folders, so use it as a first pass. `--llm` sends batches of 40 Inbox bookmarks and the folder list to the command; answers
  that name a folder that does not exist are ignored.

## Config

`bm.config.json` next to the DB (or `--config PATH`, or `$BM_CONFIG`) lets anyone describe their own folder structure; see
`bm.config.example.json`. Every key is optional.

| Key | Meaning |
| --- | --- |
| `inbox` | folder where unfiled bookmarks wait (default `bookmark_bar/Inbox`) |
| `min_score` | classifier confidence needed to move a bookmark (`--min` overrides; default 300) |
| `llm` | command (split on spaces) that `classify` uses when set; `--llm CMD` overrides it, `--heuristic` turns it off |
| `folders[].path` | a folder, usable before any bookmark is filed there |
| `folders[].description` | shown to the LLM next to the path |
| `folders[].words`, `hosts` | soft hints: they vote for the folder like five bookmarks already filed there |
| `folders[].strict` | when true, a bookmark with one of the words, or whose host is (a subdomain of) one of the hosts, goes to this folder outright; first match in file order wins |

With a config and an empty DB, `classify` can already file bookmarks into the structure you describe, and the LLM prompt
lists the configured folders (with descriptions) ahead of the folders found in the DB.

## Layout

| File | Role |
| --- | --- |
| `main.bend`, `cmd.bend`, `cli.bend` | command dispatch, commands, argument helpers |
| `chromium.bend`, `chromium_out.bend` | Chromium `Bookmarks` JSON in and out |
| `plist.bend` | XML property list parser (Safari) |
| `html_out.bend` | Netscape HTML writer |
| `cmdq.bend`, `query.bend`, `format.bend`, `date.bend` | ls/export/count/stats, filters and grouping, output formats, timestamp to ISO date |
| `store.bend`, `dbio.bend`, `io.bend` | the DB file and whole-file IO |
| `merge.bend`, `normalize.bend`, `paths.bend`, `model.bend` | merge rules, URL normalization, folder paths, the `Item` type |
| `classify.bend`, `llm.bend`, `config.bend` | word/host classifier, the LLM batch loop, the config file |
| `check.bend`, `justfile`, `lint.awk` | behavior checks, full gate, lint |

## Develop

`just check` (or the same four commands by hand: `awk -f lint.awk *.bend`, `bend main.bend -o bm` (a type error fails the build), then build and run `check.bend`) lints, typechecks and runs the behavior checks natively. Build with `bend main.bend -o bm`; `bend main.bend` runs
the checker's interpreter, which overflows on large inputs.

Bend gotchas this code works around: `Bool.pick` evaluates both branches (so a recursive call in each is exponential;
`lint.awk` rejects it), `match` takes only a parameter (give a computed value its own def), a def can call only defs
above it, and mutual recursion is not allowed (state is threaded through an argument instead). Text is held as octet
strings, so output goes through `Io.out`, not `IO.print`.

Packages: `bend-kit-json`, `bend-kit-bytes`, `bend-kit-files`, `bend-kit-process` from <https://github.com/paymog/bend-kit>.

## License

GPL-3.0-or-later. See `LICENSE`.
