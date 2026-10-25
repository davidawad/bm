# LLM-assisted filing. The command (default none; --llm "claude -p --model haiku") receives a prompt on stdin that lists the
# existing folders and a batch of Inbox bookmarks, and must answer one `N|folder path` line per bookmark. Answers naming a
# folder that does not exist are ignored, so a bad reply can only leave a bookmark in the Inbox.
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-kit-process@0.4.0.1/process.bend as Proc
import ./model.bend as Model
import ./dbio.bend as Dbio
import ./config.bend as Config

def batch.size() -> Nat:
  40n

# ---- folders ----

def count.one(p: Map<&2, U32> & U32, +folder: String) -> Map<&2, U32>:
  match p:
    case (m, n):
      Map.set(&2, U32, m, folder, (n + 1 : U32))

def count.folders(items: List<&2, Model.Item>, +skip: String, +m: Map<&2, U32>) -> Map<&2, U32>:
  match items:
    case Nil{}:
      m
    case Con{it, t}:
      Model.Item{+folder, title, url, added} = it
      count.folders(t, skip, Bool.pick(Map<&2, U32>, String.eq(folder, skip), m, count.one(Map.get(U32, 0, m, folder), folder)))

def folder.line(kv: Sigma<&2, &2, String, _ => U32>) -> String:
  match kv:
    case Tuple{k, v}:
      String.concat([k, "\n"])

def folder.lines(kvs: List<&2, Sigma<&2, &2, String, _ => U32>>) -> String:
  match kvs:
    case Nil{}:
      ""
    case Con{kv, t}:
      String.append(folder.line(kv), folder.lines(t))

def known.set(kvs: List<&2, Sigma<&2, &2, String, _ => U32>>, s: Set()) -> Set():
  match kvs:
    case Nil{}:
      s
    case Con{Tuple{k, v}, t}:
      known.set(t, Set.add(s, k))

# ---- batches ----

# Inbox items from position off, at most n of them, as "N|title|url" lines numbered from 1.
def batch.lines(items: List<&2, Model.Item>, +inbox: String, +off: Nat, +n: Nat, +i: Nat) -> String:
  match items:
    case Nil{}:
      ""
    case Con{it, t}:
      Model.Item{+folder, +title, +url, added} = it
      +here = Bool.and(String.eq(folder, inbox), Bool.and(Nat.is_ge(i, off), Nat.is_lt(i, Nat.add(off, n))))
      String.append(Bool.pick(String, here, String.concat([Nat.show(Nat.add(Nat.sub(i, off), 1n)), "|", title, "|", url, "\n"]), ""), batch.lines(t, inbox, off, n, Bool.pick(Nat, String.eq(folder, inbox), 1n+i, i)))

def inbox.count(items: List<&2, Model.Item>, +inbox: String) -> Nat:
  match items:
    case Nil{}:
      0n
    case Con{it, t}:
      Model.Item{+folder, title, url, added} = it
      Nat.add(Bool.pick(Nat, String.eq(folder, inbox), 1n, 0n), inbox.count(t, inbox))

def prompt(+folders: String, +lines: String) -> String:
  String.concat(["You file bookmarks into an existing folder tree. These are the folders:\n", folders, "\nFor each numbered bookmark below, answer with exactly one line `N|<folder>`, choosing the best folder from the list above and copying it exactly. If none fits, answer `N|bookmark_bar/Inbox`. Output only those lines.\n\n", lines])

# ---- answers ----

# "N|folder" -> (N as text, folder)
def answer.parts(ps: List<&2, String>) -> String & String:
  match ps:
    case Nil{}:
      ("", "")
    case Con{n, rest}:
      (String.trim(n), String.trim(String.join(rest, "|")))

def answer(line: String) -> String & String:
  answer.parts(String.split(line, '|'))

def answers.keep(p: Set() & Bool, +n: String, +folder: String, +m: Map<&2, String>) -> Map<&2, String>:
  match p:
    case (known2, ok):
      Bool.pick(Map<&2, String>, ok, Map.set(&2, String, m, n, folder), m)

def answers.put(a: String & String, +known: Set(), m: Map<&2, String>) -> Map<&2, String>:
  match a:
    case (n, +folder):
      answers.keep(Set.has(known, folder), n, folder, m)

def answers.go(lines: List<&2, String>, +known: Set(), m: Map<&2, String>) -> Map<&2, String>:
  match lines:
    case Nil{}:
      m
    case Con{l, t}:
      answers.go(t, known, answers.put(answer(l), known, m))

def answers(text: String, +known: Set()) -> Map<&2, String>:
  answers.go(String.lines(text), known, Map.new(&2, String))

# Apply the answers to the batch's items; every other item is unchanged.
def reassign.one(p: Map<&2, String> & String, +f0: String) -> String:
  match p:
    case (m, f):
      f

def reassign(items: List<&2, Model.Item>, +inbox: String, +off: Nat, +n: Nat, +i: Nat, +m: Map<&2, String>) -> List<&2, Model.Item>:
  match items:
    case Nil{}:
      []
    case Con{it, t}:
      Model.Item{+folder, title, url, added} = it
      +here = Bool.and(String.eq(folder, inbox), Bool.and(Nat.is_ge(i, off), Nat.is_lt(i, Nat.add(off, n))))
      Model.Item{Bool.pick(String, here, reassign.one(Map.get(String, folder, m, Nat.show(Nat.add(Nat.sub(i, off), 1n))), folder), folder), title, url, added} <> reassign(t, inbox, off, n, Bool.pick(Nat, String.eq(folder, inbox), 1n+i, i), m)

# ---- the loop: one process call per batch of Inbox bookmarks ----

# The DB and how many Inbox bookmarks earlier batches have already covered.
type Ls is Data:
  Ls{items: List<&2, Model.Item>, off: Nat}

def folders.of(+items: List<&2, Model.Item>, +inbox: String) -> List<&2, Sigma<&2, &2, String, _ => U32>>:
  Map.to_list(&2, U32, count.folders(items, inbox, Map.new(&2, U32)))

# Configured folders, with their descriptions, listed first so empty folders are still choices.
def cfg.lines(fs: List<&2, Config.Fh>) -> String:
  match fs:
    case Nil{}:
      ""
    case Con{fh, t}:
      Config.Fh{+path, +desc, hosts, words, strict} = fh
      String.append(Bool.pick(String, String.is_empty(desc), String.concat([path, "\n"]), String.concat([path, "  (", desc, ")\n"])), cfg.lines(t))

def cfg.known(fs: List<&2, Config.Fh>, s: Set()) -> Set():
  match fs:
    case Nil{}:
      s
    case Con{fh, t}:
      Config.Fh{path, desc, hosts, words, strict} = fh
      cfg.known(t, Set.add(s, path))

def ls.items(st: Ls) -> List<&2, Model.Item>:
  Ls{items, off} = st
  items

def prompt.of(st: Ls, +inbox: String, +fs: List<&2, Config.Fh>) -> Bytes.Bytes:
  Ls{+items, +off} = st
  Bytes.from_string(prompt(String.append(cfg.lines(fs), folder.lines(folders.of(items, inbox))), batch.lines(items, inbox, off, batch.size(), 0n)))

def fold.text(st: Ls, +inbox: String, +fs: List<&2, Config.Fh>, text: String) -> Ls:
  Ls{+items, +off} = st
  Ls{reassign(items, inbox, off, batch.size(), 0n, answers(text, cfg.known(fs, known.set(folders.of(items, inbox), Set.new())))), Nat.add(off, batch.size())}

def fold.skip(st: Ls) -> Ls:
  Ls{items, off} = st
  Ls{items, Nat.add(off, batch.size())}

def fold.ok(ok: Bool, st: Ls, +inbox: String, +fs: List<&2, Config.Fh>, out: Bytes.Bytes) -> Ls:
  match ok:
    case True{}:
      fold.text(st, inbox, fs, Bytes.to_string(out))
    case False{}:
      fold.skip(st)

def fold.triple(st: Ls, +inbox: String, +fs: List<&2, Config.Fh>, t: U32 & Bytes.Bytes & Bytes.Bytes) -> Ls:
  match t:
    case (status, out, err):
      fold.ok(U32.is_eq(status, 0), st, inbox, fs, out)

# A failed or non-zero call skips the batch; its bookmarks stay in the Inbox.
def fold(st: Ls, +inbox: String, +fs: List<&2, Config.Fh>, r: Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>) -> Ls:
  match r:
    case Fail{e}:
      fold.skip(st)
    case Done{t}:
      fold.triple(st, inbox, fs, t)

def run.loop(fuel: Nat, +st: Ls, +cmd: String, +args: List<&2, String>, +db: String, +inbox: String, +fs: List<&2, Config.Fh>) -> IO(Unit):
  match fuel:
    case 0n:
      Dbio.save(db, ls.items(st))
    case 1n+p:
      do IO<Unit>:
        Dbio.save(db, ls.items(st))
        r : Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes> <- Proc.run(cmd, args, [], ".", prompt.of(st, inbox, fs))
        run.loop(p, fold(st, inbox, fs, r), cmd, args, db, inbox, fs)

def batches(+items: List<&2, Model.Item>, +inbox: String) -> Nat:
  Nat.add(Nat.div(inbox.count(items, inbox), batch.size()), 1n)

# Run the LLM command over every Inbox bookmark. cmdline is split on spaces: program, then arguments.
def run(+items: List<&2, Model.Item>, +cmdline: String, +db: String, +inbox: String, +fs: List<&2, Config.Fh>) -> IO(Unit):
  run.loop(batches(items, inbox), Ls{items, 0n}, Maybe.default(&2, String, List.head(&2, String, String.split(cmdline, ' ')), ""), List.tail(&2, String, String.split(cmdline, ' ')), db, inbox, fs)
