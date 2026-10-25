# The bm commands. Each takes the full argument list (command name first), the DB path and $HOME.
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-kit-files@0.2.0.0/files.bend as Fs
import ./model.bend as Model
import ./io.bend as Io
import ./dbio.bend as Dbio
import ./cli.bend as Cli
import ./browsers.bend as Browsers
import ./chromium.bend as Chromium
import ./chromium_out.bend as Out
import ./html_out.bend as Html
import ./merge.bend as Merge
import ./classify.bend as Classify
import ./plist.bend as Plist
import ./llm.bend as Llm
import ./config.bend as Config
import bend-kit-process@0.4.0.1/process.bend as Proc

def summary(added: Nat, skipped: Nat, suffix: String) -> String:
  String.concat([Nat.show(added), " new, ", Nat.show(skipped), " already known", suffix])

# ---- pull ----

def pull.save(+db: String, rep: List<&2, Model.Item> & Nat & Nat, suffix: String) -> IO(Unit):
  match rep:
    case (merged, added, skipped):
      do IO<Unit>:
        Dbio.save(db, merged)
        Io.out.line(summary(added, skipped, suffix))

def pull.dry(rep: List<&2, Model.Item> & Nat & Nat) -> IO(Unit):
  match rep:
    case (merged, added, skipped):
      Io.out.line(summary(added, skipped, " (dry run)"))

def pull.finish(dry: Bool, +db: String, rep: List<&2, Model.Item> & Nat & Nat) -> IO(Unit):
  match dry:
    case True{}:
      pull.dry(rep)
    case False{}:
      pull.save(db, rep, "")

def pull.news(m: Maybe<&1, List<&2, Model.Item>>, +dry: Bool, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "not a Chromium Bookmarks file")
    case Some{news}:
      do IO<Unit>:
        cur : List<&2, Model.Item> <- Dbio.load(db)
        pull.finish(dry, db, Merge.merge(cur, news, Config.inbox.of(cfg)))

def pull.read(+path: String, +dry: Bool, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  do IO<Unit>:
    b : Bytes.Bytes <- Io.read.file(path)
    pull.news(Chromium.read(b), dry, db, cfg)

def pull.known(ok: Bool, +path: String, +dry: Bool, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match ok:
    case True{}:
      pull.read(path, dry, db, cfg)
    case False{}:
      IO.die(Unit, 1, "unknown browser; use chrome, helium, brave, edge, browseros, or file with --path")

# Safari: plutil turns the binary plist into XML, which plist.bend reads. The file needs Full Disk Access.
def pull.safari.news(m: Maybe<&1, List<&2, Model.Item>>, +dry: Bool, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  pull.news(m, dry, db, cfg)

def pull.safari.out(ok: Bool, out: Bytes.Bytes, +dry: Bool, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match ok:
    case True{}:
      pull.safari.news(Chromium.read.safari(Plist.parse(Bytes.to_string(out))), dry, db, cfg)
    case False{}:
      IO.die(Unit, 1, "plutil could not read the Safari file (grant the terminal Full Disk Access, or pass --path to a copy)")

def pull.safari.result(r: Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>, +dry: Bool, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "could not run plutil")
    case Done{triple}:
      match triple:
        case (status, out, err):
          pull.safari.out(U32.is_eq(status, 0), out, dry, db, cfg)

def pull.safari(+path: String, +dry: Bool, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes> <- Proc.run("plutil", ["-convert", "xml1", "-o", "-", path], [], ".", Bytes.from_string(""))
    pull.safari.result(r, dry, db, cfg)

def pull.pick(safari: Bool, ok: Bool, +path: String, +dry: Bool, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match safari:
    case True{}:
      pull.safari(path, dry, db, cfg)
    case False{}:
      pull.known(ok, path, dry, db, cfg)

def pull(+args: List<&2, String>, +db: String, +home: String, +cfg: Config.Cfg) -> IO(Unit):
  pull.pick(Browsers.safari(Cli.nth(Cli.pos(args), 1n)), Browsers.known(Cli.nth(Cli.pos(args), 1n)), Browsers.resolve(home, Cli.nth(Cli.pos(args), 1n), Cli.opt(args, "--path")), Cli.flag(args, "--dry-run"), db, cfg)

# ---- push ----

def push.backup(there: Bool, +path: String) -> IO(Unit):
  match there:
    case False{}:
      IO.pure(Unit, Unit{})
    case True{}:
      do IO<Unit>:
        b : Bytes.Bytes <- Io.read.file(path)
        Io.write.file(String.append(path, ".bm-backup"), b)

def push.write(items: List<&2, Model.Item>, +path: String) -> IO(Unit):
  do IO<Unit>:
    there : Bool <- Fs.exists(path)
    push.backup(there, path)
    Io.write.file(path, Out.render(items))

def push.items(items: List<&2, Model.Item>, +path: String) -> IO(Unit):
  do IO<Unit>:
    push.write(items, path)
    Io.out.line(String.append("wrote ", path))

def push.known(ok: Bool, +path: String, +db: String) -> IO(Unit):
  match ok:
    case True{}:
      do IO<Unit>:
        items : List<&2, Model.Item> <- Dbio.load(db)
        push.items(items, path)
    case False{}:
      IO.die(Unit, 1, "unknown browser; use chrome, helium, brave, edge, browseros, or file with --path")

def push(+args: List<&2, String>, +db: String, +home: String) -> IO(Unit):
  push.known(Browsers.known(Cli.nth(Cli.pos(args), 1n)), Browsers.resolve(home, Cli.nth(Cli.pos(args), 1n), Cli.opt(args, "--path")), db)

# ---- export-html ----

def html.to(items: List<&2, Model.Item>, out: Maybe<&2, String>) -> IO(Unit):
  match out:
    case None{}:
      Io.out(Html.render(items))
    case Some{p}:
      Io.write.file(p, Bytes.from_string(Html.render(items)))

def export.html(+args: List<&2, String>, +db: String) -> IO(Unit):
  do IO<Unit>:
    items : List<&2, Model.Item> <- Dbio.load(db)
    html.to(items, Cli.opt(args, "--out"))

# ---- find / mv / rm / add ----

def match.line(it: Model.Item) -> String:
  Model.Item{folder, title, url, added} = it
  String.concat([folder, "\t", title, "\t", url, "\n"])

def hit(+it: Model.Item, +q: String) -> Bool:
  Model.Item{folder, title, url, added} = it
  Bool.or(String.contains(String.to_lower(title), q), String.contains(String.to_lower(url), q))

def find.lines(+items: List<&2, Model.Item>, +q: String) -> String:
  match items:
    case Nil{}:
      ""
    case Con{it, t}:
      String.append(Bool.pick(String, hit(it, q), match.line(it), ""), find.lines(t, q))

def find(+args: List<&2, String>, +db: String) -> IO(Unit):
  do IO<Unit>:
    items : List<&2, Model.Item> <- Dbio.load(db)
    Io.out(find.lines(items, String.to_lower(Cli.nth(Cli.pos(args), 1n))))

def move.one(+it: Model.Item, +q: String, +folder: String) -> Model.Item:
  Model.Item{f0, title, url, added} = it
  Bool.pick(Model.Item, hit(it, q), Model.Item{folder, title, url, added}, Model.Item{f0, title, url, added})

def move.all(+items: List<&2, Model.Item>, +q: String, +folder: String) -> List<&2, Model.Item>:
  match items:
    case Nil{}:
      []
    case Con{it, t}:
      move.one(it, q, folder) <> move.all(t, q, folder)

def drop.keep(gone: Bool, it: Model.Item, rest: List<&2, Model.Item>) -> List<&2, Model.Item>:
  match gone:
    case True{}:
      rest
    case False{}:
      it <> rest

def drop.all(+items: List<&2, Model.Item>, +q: String) -> List<&2, Model.Item>:
  match items:
    case Nil{}:
      []
    case Con{it, t}:
      drop.keep(hit(it, q), it, drop.all(t, q))

def mv(+args: List<&2, String>, +db: String) -> IO(Unit):
  do IO<Unit>:
    items : List<&2, Model.Item> <- Dbio.load(db)
    Dbio.save(db, move.all(items, String.to_lower(Cli.nth(Cli.pos(args), 1n)), Cli.nth(Cli.pos(args), 2n)))

def rm(+args: List<&2, String>, +db: String) -> IO(Unit):
  do IO<Unit>:
    items : List<&2, Model.Item> <- Dbio.load(db)
    Dbio.save(db, drop.all(items, String.to_lower(Cli.nth(Cli.pos(args), 1n))))

def add.item(+url: String, title: Maybe<&2, String>, folder: Maybe<&2, String>, inbox: String) -> Model.Item:
  Model.Item{Maybe.default(&2, String, folder, inbox), Maybe.default(&2, String, title, url), url, "0"}

def add.save(+db: String, rep: List<&2, Model.Item> & Nat & Nat) -> IO(Unit):
  match rep:
    case (merged, added, skipped):
      do IO<Unit>:
        Dbio.save(db, merged)
        Io.out.line(summary(added, skipped, ""))

def add(+args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  do IO<Unit>:
    items : List<&2, Model.Item> <- Dbio.load(db)
    add.save(db, Merge.merge(items, [add.item(Cli.nth(Cli.pos(args), 1n), Cli.opt(args, "--title"), Cli.opt(args, "--folder"), Config.inbox.of(cfg))], Config.inbox.of(cfg)))

# ---- tree ----

# Every folder prefix up to the given depth, one entry per bookmark.
def prefixes(+segs: List<&2, String>, +d: Nat, +acc: List<&2, String>) -> List<&2, String>:
  match d:
    case 0n:
      acc
    case 1n+p:
      prefixes(segs, p, String.join(List.take(&2, String, segs, 1n+p), "/") <> acc)

def all.prefixes(+items: List<&2, Model.Item>, +depth: Nat) -> List<&2, String>:
  match items:
    case Nil{}:
      []
    case Con{it, t}:
      Model.Item{+folder, title, url, added} = it
      +segs = String.split(folder, '/')
      prefixes(segs, Nat.min(depth, List.length(&2, String, segs)), all.prefixes(t, depth))

def tree.line(+path: String, n: Nat) -> String:
  +segs = String.split(path, '/')
  String.concat([String.repeat("  ", Nat.sub(List.length(&2, String, segs), 1n)), Maybe.default(&2, String, List.last(&2, String, segs), ""), " (", Nat.show(n), ")\n"])

# One finished run as a line; nothing before the first prefix.
def tree.flush(+cur: String, +n: Nat) -> String:
  Bool.pick(String, Nat.is_eq(n, 0n), "", tree.line(cur, n))

# Sorted prefixes -> "name (count)" lines. Bool.pick runs both branches, so only the data differs and there is one recursive call.
def tree.runs(+sorted: List<&2, String>, +cur: String, +n: Nat) -> String:
  match sorted:
    case Nil{}:
      tree.flush(cur, n)
    case Con{p, t}:
      +same = String.eq(p, cur)
      String.append(Bool.pick(String, same, "", tree.flush(cur, n)), tree.runs(t, Bool.pick(String, same, cur, p), Bool.pick(Nat, same, 1n+n, 1n)))

def tree(+args: List<&2, String>, +db: String) -> IO(Unit):
  do IO<Unit>:
    items : List<&2, Model.Item> <- Dbio.load(db)
    Io.out(tree.runs(List.sort(~String, ~String.is_le, all.prefixes(items, Cli.nat.or(Nat.read(Maybe.default(&2, String, Cli.opt(args, "--depth"), "3")), 3n))), "", 0n))

# ---- classify / eval ----

def cl.line(+min: U32, cl: Classify.Cl) -> String:
  Classify.Cl{item, +folder, +score} = cl
  Model.Item{f0, title, url, added} = item
  String.concat([Bool.pick(String, U32.is_lt(score, min), "  ?  ", "  ok "), U32.show(score), "\t", folder, "\t", title, "\t", url, "\n"])

def cl.lines(+min: U32, cls: List<&2, Classify.Cl>) -> String:
  match cls:
    case Nil{}:
      ""
    case Con{cl, t}:
      String.append(cl.line(min, cl), cl.lines(min, t))

def classify.save(apply: Bool, +db: String, +items: List<&2, Model.Item>, +min: U32, +cfg: Config.Cfg) -> IO(Unit):
  match apply:
    case False{}:
      IO.pure(Unit, Unit{})
    case True{}:
      Dbio.save(db, Classify.apply.all(Classify.index(items, Config.inbox.of(cfg), Config.folders.of(cfg)), Config.inbox.of(cfg), min, items))

def classify.run(+items: List<&2, Model.Item>, +db: String, +min: U32, +apply: Bool, +cfg: Config.Cfg) -> IO(Unit):
  do IO<Unit>:
    Io.out(cl.lines(min, Classify.suggest(items, Config.inbox.of(cfg), Config.folders.of(cfg))))
    classify.save(apply, db, items, min, cfg)

# --min beats the config's min_score, which beats the built-in 300.
def min.of(+args: List<&2, String>, +cfg: Config.Cfg) -> U32:
  Cli.u32.or(U32.read(Maybe.default(&2, String, Cli.opt(args, "--min"), U32.show(Config.min.of(cfg)))), 300)

def llm.cfg(heuristic: Bool, +cfgllm: String) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, Bool.or(heuristic, String.is_empty(cfgllm)), None{}, Some{cfgllm})

# An explicit --llm wins; otherwise the config's llm is used unless --heuristic is given.
def llm.cmd(explicit: Maybe<&2, String>, +cfgllm: String, heuristic: Bool) -> Maybe<&2, String>:
  match explicit:
    case Some{c}:
      Some{c}
    case None{}:
      llm.cfg(heuristic, cfgllm)

def classify.pick(llm: Maybe<&2, String>, +items: List<&2, Model.Item>, +db: String, +min: U32, +apply: Bool, +cfg: Config.Cfg) -> IO(Unit):
  match llm:
    case Some{c}:
      Llm.run(items, c, db, Config.inbox.of(cfg), Config.folders.of(cfg))
    case None{}:
      classify.run(items, db, min, apply, cfg)

def classify(+args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  do IO<Unit>:
    items : List<&2, Model.Item> <- Dbio.load(db)
    classify.pick(llm.cmd(Cli.opt(args, "--llm"), Config.llm.of(cfg), Cli.flag(args, "--heuristic")), items, db, min.of(args, cfg), Cli.flag(args, "--apply"), cfg)

def ev.report(ev: Classify.Ev) -> IO(Unit):
  Classify.Ev{ok, bad, none} = ev
  Io.out.line(String.concat(["right ", U32.show(ok), ", wrong ", U32.show(bad), ", below threshold ", U32.show(none)]))

def eval(+args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  do IO<Unit>:
    items : List<&2, Model.Item> <- Dbio.load(db)
    ev.report(Classify.evaluate(items, Cli.u32.or(U32.read(Maybe.default(&2, String, Cli.opt(args, "--every"), "10")), 10), Config.inbox.of(cfg), min.of(args, cfg), Cli.nat.or(Nat.read(Maybe.default(&2, String, Cli.opt(args, "--depth"), "0")), 0n), Config.folders.of(cfg)))
