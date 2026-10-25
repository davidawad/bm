# Query commands: ls / export (filter, sort, project, format), count (group by a field) and stats.
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import ./model.bend as Model
import ./io.bend as Io
import ./dbio.bend as Dbio
import ./cli.bend as Cli
import ./config.bend as Config
import ./format.bend as Format
import ./query.bend as Query
import ./html_out.bend as Html
import ./classify.bend as Classify

# ---- options -> query ----

def opt.or(m: Maybe<&2, String>, +d: String) -> String:
  Maybe.default(&2, String, m, d)

def q.with(+use: Bool, +args: List<&2, String>, +items: List<&2, Model.Item>) -> Query.Q:
  Query.Q{opt.or(Cli.opt(args, "--folder"), ""), String.to_lower(opt.or(Cli.opt(args, "--host"), "")), String.to_lower(opt.or(Cli.opt(args, "--text"), "")), opt.or(Cli.opt(args, "--since"), ""), opt.or(Cli.opt(args, "--until"), ""), Bool.pick(Set(), use, Query.dupes.of(items), Set.new()), use}

def q.of(+args: List<&2, String>, +items: List<&2, Model.Item>) -> Query.Q:
  q.with(Cli.flag(args, "--dupes"), args, items)

# Human formats default to three columns; data formats carry everything.
def human(+fmt: String) -> Bool:
  Bool.or(Bool.or(String.eq(fmt, "table"), String.eq(fmt, "md")), String.eq(fmt, "tsv"))

def fields.of(+args: List<&2, String>, +fmt: String) -> List<&2, String>:
  String.split(opt.or(Cli.opt(args, "--fields"), Bool.pick(String, human(fmt), "folder,title,url", "folder,title,url,added,date")), ',')

def formats() -> List<&2, String>:
  ["table", "tsv", "csv", "json", "jsonl", "toon", "md", "html", "urls"]

# ---- shaping the selection ----

def sorted.by(has: Bool, +f: String, +items: List<&2, Model.Item>) -> List<&2, Model.Item>:
  match has:
    case True{}:
      Query.sort.by(f, items)
    case False{}:
      items

def flipped(rev: Bool, +items: List<&2, Model.Item>) -> List<&2, Model.Item>:
  match rev:
    case True{}:
      List.reverse(&2, Model.Item, items)
    case False{}:
      items

def limited(+n: Maybe<&2, Nat>, +items: List<&2, Model.Item>) -> List<&2, Model.Item>:
  match n:
    case Some{k}:
      List.take(&2, Model.Item, items, k)
    case None{}:
      items

def shape(+args: List<&2, String>, +items: List<&2, Model.Item>) -> List<&2, Model.Item>:
  limited(Nat.read(opt.or(Cli.opt(args, "--limit"), "x")), flipped(Cli.flag(args, "--reverse"), sorted.by(Maybe.is_some(&2, String, Cli.opt(args, "--sort")), opt.or(Cli.opt(args, "--sort"), ""), Query.select(q.of(args, items), items))))

# ---- rendering ----

def url.lines(rows: List<&2, Format.Row>) -> String:
  match rows:
    case Nil{}:
      ""
    case Con{r, t}:
      Format.Row{cells} = r
      String.concat([Maybe.default(&2, String, List.head(&2, String, cells), ""), "\n", url.lines(t)])

def r8(is_html: Bool, is_urls: Bool, items: List<&2, Model.Item>, rows: List<&2, Format.Row>) -> String:
  match is_html:
    case True{}:
      Html.render(items)
    case False{}:
      match is_urls:
        case True{}:
          url.lines(rows)
        case False{}:
          ""

def r7(is_md: Bool, is_table: Bool, is_html: Bool, is_urls: Bool, +name: String, +fields: List<&2, String>, items: List<&2, Model.Item>, rows: List<&2, Format.Row>) -> String:
  match is_md:
    case True{}:
      Format.md(fields, rows)
    case False{}:
      match is_table:
        case True{}:
          Format.table(fields, rows)
        case False{}:
          r8(is_html, is_urls, items, rows)

def r6(is_toon: Bool, is_md: Bool, is_table: Bool, is_html: Bool, is_urls: Bool, +name: String, +fields: List<&2, String>, items: List<&2, Model.Item>, rows: List<&2, Format.Row>) -> String:
  match is_toon:
    case True{}:
      Format.toon(name, fields, rows)
    case False{}:
      r7(is_md, is_table, is_html, is_urls, name, fields, items, rows)

def r5(is_tsv: Bool, is_toon: Bool, is_md: Bool, is_table: Bool, is_html: Bool, is_urls: Bool, +name: String, +fields: List<&2, String>, items: List<&2, Model.Item>, rows: List<&2, Format.Row>) -> String:
  match is_tsv:
    case True{}:
      Format.tsv(fields, rows)
    case False{}:
      r6(is_toon, is_md, is_table, is_html, is_urls, name, fields, items, rows)

def r4(is_jsonl: Bool, is_tsv: Bool, is_toon: Bool, is_md: Bool, is_table: Bool, is_html: Bool, is_urls: Bool, +name: String, +fields: List<&2, String>, items: List<&2, Model.Item>, rows: List<&2, Format.Row>) -> String:
  match is_jsonl:
    case True{}:
      Format.jsonl(fields, rows)
    case False{}:
      r5(is_tsv, is_toon, is_md, is_table, is_html, is_urls, name, fields, items, rows)

def r3(is_csv: Bool, is_jsonl: Bool, is_tsv: Bool, is_toon: Bool, is_md: Bool, is_table: Bool, is_html: Bool, is_urls: Bool, +name: String, +fields: List<&2, String>, items: List<&2, Model.Item>, rows: List<&2, Format.Row>) -> String:
  match is_csv:
    case True{}:
      Format.csv(fields, rows)
    case False{}:
      r4(is_jsonl, is_tsv, is_toon, is_md, is_table, is_html, is_urls, name, fields, items, rows)

def r2(is_json: Bool, is_csv: Bool, is_jsonl: Bool, is_tsv: Bool, is_toon: Bool, is_md: Bool, is_table: Bool, is_html: Bool, is_urls: Bool, +name: String, +fields: List<&2, String>, items: List<&2, Model.Item>, rows: List<&2, Format.Row>) -> String:
  match is_json:
    case True{}:
      Format.json(fields, rows)
    case False{}:
      r3(is_csv, is_jsonl, is_tsv, is_toon, is_md, is_table, is_html, is_urls, name, fields, items, rows)

def render(+fmt: String, +name: String, +fields: List<&2, String>, items: List<&2, Model.Item>, rows: List<&2, Format.Row>) -> String:
  r2(String.eq(fmt, "json"), String.eq(fmt, "csv"), String.eq(fmt, "jsonl"), String.eq(fmt, "tsv"), String.eq(fmt, "toon"), String.eq(fmt, "md"), String.eq(fmt, "table"), String.eq(fmt, "html"), String.eq(fmt, "urls"), name, fields, items, rows)

def emit(out: Maybe<&2, String>, +text: String) -> IO(Unit):
  match out:
    case Some{p}:
      Io.write.file(p, Bytes.from_string(text))
    case None{}:
      Io.out(text)

def bad.format(ok: Bool, +fmt: String, +text: String, out: Maybe<&2, String>) -> IO(Unit):
  match ok:
    case True{}:
      emit(out, text)
    case False{}:
      IO.die(Unit, 2, String.concat(["unknown format ", fmt, "; use ", String.join(formats(), ", ")]))

# ---- ls / export ----

def ls.out(+args: List<&2, String>, +fmt: String, +shown: List<&2, Model.Item>) -> IO(Unit):
  bad.format(Cli.member(fmt, formats()), fmt, render(fmt, "bookmarks", Bool.pick(List<&2, String>, String.eq(fmt, "urls"), ["url"], fields.of(args, fmt)), shown, Query.rows(Bool.pick(List<&2, String>, String.eq(fmt, "urls"), ["url"], fields.of(args, fmt)), shown)), Cli.opt(args, "--out"))

def ls.show(+args: List<&2, String>, +fmt: String, +items: List<&2, Model.Item>) -> IO(Unit):
  ls.out(args, fmt, shape(args, items))

# ls prints a table, export prints json; --format picks any other.
def ls(+args: List<&2, String>, +db: String, +dfmt: String) -> IO(Unit):
  do IO<Unit>:
    items : List<&2, Model.Item> <- Dbio.load(db)
    ls.show(args, opt.or(Cli.opt(args, "--format"), dfmt), items)

# ---- count ----

def top(n: Maybe<&2, Nat>, rows: List<&2, Format.Row>) -> List<&2, Format.Row>:
  match n:
    case Some{k}:
      List.take(&2, Format.Row, rows, k)
    case None{}:
      rows

def count.out(+args: List<&2, String>, +fmt: String, +by: String, +shown: List<&2, Model.Item>) -> IO(Unit):
  bad.format(Cli.member(fmt, formats()), fmt, render(fmt, "counts", [by, "count"], shown, top(Nat.read(opt.or(Cli.opt(args, "--limit"), "x")), Query.count.rows(by, shown))), Cli.opt(args, "--out"))

def count.go(+args: List<&2, String>, +items: List<&2, Model.Item>) -> IO(Unit):
  count.out(args, opt.or(Cli.opt(args, "--format"), "table"), opt.or(Cli.opt(args, "--by"), "folder"), Query.select(q.of(args, items), items))

def count(+args: List<&2, String>, +db: String) -> IO(Unit):
  do IO<Unit>:
    items : List<&2, Model.Item> <- Dbio.load(db)
    count.go(args, items)

# ---- stats ----

def distinct(+f: String, items: List<&2, Model.Item>) -> Nat:
  Map.size(&2, U32, Query.group(f, items, Map.new(&2, U32)))

# The first non-empty date in a list ordered by date. Bool.pick runs both branches; there is one recursive call, so it stays linear.
def first.date.of(+d: String, +rest: String) -> String:
  Bool.pick(String, String.is_empty(d), rest, d)

def first.date(items: List<&2, Model.Item>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{it, t}:
      first.date.of(Query.cell("date", it), first.date(t))

def stat(+k: String, +v: String) -> Format.Row:
  Format.Row{[k, v]}

def stats.dated(+items: List<&2, Model.Item>, +inbox: String, +by_date: List<&2, Model.Item>) -> List<&2, Format.Row>:
  [stat("bookmarks", Nat.show(List.length(&2, Model.Item, items))), stat("folders", Nat.show(distinct("folder", items))), stat("hosts", Nat.show(distinct("host", items))), stat("inbox", Nat.show(List.length(&2, Model.Item, Classify.in.inbox(inbox, items)))), stat("duplicate_urls", Nat.show(Set.size(Query.dupes.of(items)))), stat("oldest", first.date(by_date)), stat("newest", first.date(List.reverse(&2, Model.Item, by_date)))]

def stats.rows(+items: List<&2, Model.Item>, +inbox: String) -> List<&2, Format.Row>:
  stats.dated(items, inbox, Query.sort.by("date", items))

def stats.go(+args: List<&2, String>, +items: List<&2, Model.Item>, +inbox: String) -> IO(Unit):
  bad.format(Cli.member(opt.or(Cli.opt(args, "--format"), "table"), formats()), opt.or(Cli.opt(args, "--format"), "table"), render(opt.or(Cli.opt(args, "--format"), "table"), "stats", ["metric", "value"], [], stats.rows(items, inbox)), Cli.opt(args, "--out"))

def stats(+args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  do IO<Unit>:
    items : List<&2, Model.Item> <- Dbio.load(db)
    stats.go(args, items, Config.inbox.of(cfg))
