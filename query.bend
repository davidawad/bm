# Filtering, sorting, grouping and projecting bookmarks into rows for the output formats.
import Base
import ./model.bend as Model
import ./date.bend as Date
import ./format.bend as Format
import ./normalize.bend as Norm
import ./classify.bend as Classify

# Selection: empty text means "no constraint". since/until are ISO dates (YYYY-MM-DD) compared with the bookmark's date.
type Q is Data:
  Q{folder: String, host: String, text: String, since: String, until: String, dupes: Set(), use_dupes: Bool}

def first.seg(xs: List<&2, String>) -> String:
  Maybe.default(&2, String, List.head(&2, String, xs), "")

def host.of(+url: String) -> String:
  String.to_lower(Classify.host(url))

# The value of one named field for a bookmark.
def cell(+f: String, +it: Model.Item) -> String:
  Model.Item{+folder, +title, +url, +added} = it
  Bool.pick(String, String.eq(f, "folder"), folder,
  Bool.pick(String, String.eq(f, "title"), title,
  Bool.pick(String, String.eq(f, "url"), url,
  Bool.pick(String, String.eq(f, "added"), added,
  Bool.pick(String, String.eq(f, "date"), Date.iso(added),
  Bool.pick(String, String.eq(f, "year"), String.take(Date.iso(added), 4n),
  Bool.pick(String, String.eq(f, "month"), String.take(Date.iso(added), 7n),
  Bool.pick(String, String.eq(f, "host"), host.of(url),
  Bool.pick(String, String.eq(f, "root"), first.seg(String.split(folder, '/')),
  Bool.pick(String, String.eq(f, "depth"), Nat.show(List.length(&2, String, String.split(folder, '/'))), ""))))))))))

def cells(+fields: List<&2, String>, +it: Model.Item) -> List<&2, String>:
  match fields:
    case Nil{}:
      []
    case Con{f, t}:
      cell(f, it) <> cells(t, it)

def rows(+fields: List<&2, String>, items: List<&2, Model.Item>) -> List<&2, Format.Row>:
  match items:
    case Nil{}:
      []
    case Con{it, t}:
      Format.Row{cells(fields, it)} <> rows(fields, t)

# ---- filters ----

def blank(+s: String) -> Bool:
  String.is_empty(s)

def in.folder(+folder: String, +p: String) -> Bool:
  Bool.or(blank(p), Bool.or(String.eq(folder, p), String.starts_with(folder, String.append(p, "/"))))

def on.host(+h: String, +want: String) -> Bool:
  Bool.or(blank(want), Bool.or(String.eq(h, want), String.ends_with(h, String.append(".", want))))

def has.text(+it: Model.Item, +q: String) -> Bool:
  Model.Item{folder, +title, +url, added} = it
  Bool.or(blank(q), String.contains(String.to_lower(String.concat([title, " ", url])), q))

# Dates compare as text; a bookmark with no date cannot satisfy since/until.
def after(+it: Model.Item, +since: String) -> Bool:
  Bool.or(blank(since), String.is_ge(cell("date", it), since))

def before(+it: Model.Item, +until: String) -> Bool:
  Bool.or(blank(until), Bool.and(Bool.not(blank(cell("date", it))), String.is_le(String.take(cell("date", it), 10n), until)))

def dupe.has(p: Set() & Bool) -> Bool:
  match p:
    case (s, b):
      b

def dupe.ok(use: Bool, dupes: Set(), +it: Model.Item) -> Bool:
  Bool.or(Bool.not(use), dupe.has(Set.has(dupes, Norm.normalize(cell("url", it)))))

def keep(q: Q, +it: Model.Item) -> Bool:
  Q{+folder, +host, +text, +since, +until, +dupes, +use} = q
  Bool.and(Bool.and(Bool.and(in.folder(cell("folder", it), folder), on.host(cell("host", it), host)), Bool.and(has.text(it, text), after(it, since))), Bool.and(before(it, until), dupe.ok(use, dupes, it)))

def select.keep(ok: Bool, it: Model.Item, rest: List<&2, Model.Item>) -> List<&2, Model.Item>:
  match ok:
    case True{}:
      it <> rest
    case False{}:
      rest

def select(+q: Q, items: List<&2, Model.Item>) -> List<&2, Model.Item>:
  match items:
    case Nil{}:
      []
    case Con{+it, t}:
      select.keep(keep(q, it), it, select(q, t))

# URLs that appear more than once (normalized).
def count.url(p: Map<&2, U32> & U32, +k: String) -> Map<&2, U32>:
  match p:
    case (m, n):
      Map.set(&2, U32, m, k, (n + 1 : U32))

def urls.count(items: List<&2, Model.Item>, +m: Map<&2, U32>) -> Map<&2, U32>:
  match items:
    case Nil{}:
      m
    case Con{it, t}:
      +k = Norm.normalize(cell("url", it))
      urls.count(t, count.url(Map.get(U32, 0, m, k), k))

def twice(kvs: List<&2, Sigma<&2, &2, String, _ => U32>>, +s: Set()) -> Set():
  match kvs:
    case Nil{}:
      s
    case Con{Tuple{+k, +v}, t}:
      twice(t, Bool.pick(Set(), U32.is_gt(v, 1), Set.add(s, k), s))

def dupes.of(+items: List<&2, Model.Item>) -> Set():
  twice(Map.to_list(&2, U32, urls.count(items, Map.new(&2, U32))), Set.new())

# ---- sorting: the key is the chosen field's value, compared as text ----

type Sk is Data:
  Sk{key: String, it: Model.Item}

def keyed(+f: String, items: List<&2, Model.Item>) -> List<&2, Sk>:
  match items:
    case Nil{}:
      []
    case Con{+it, t}:
      Sk{cell(f, it), it} <> keyed(f, t)

def le.key(a: Sk, b: Sk) -> Bool:
  Sk{ka, ia} = a
  Sk{kb, ib} = b
  String.is_le(ka, kb)

def unkey(sks: List<&2, Sk>) -> List<&2, Model.Item>:
  match sks:
    case Nil{}:
      []
    case Con{sk, t}:
      Sk{k, it} = sk
      it <> unkey(t)

def sort.by(+f: String, items: List<&2, Model.Item>) -> List<&2, Model.Item>:
  unkey(List.sort(~Sk, ~le.key, keyed(f, items)))

# ---- grouping ----

type Cnt is Data:
  Cnt{key: String, n: U32}

def group.one(p: Map<&2, U32> & U32, +k: String) -> Map<&2, U32>:
  match p:
    case (m, n):
      Map.set(&2, U32, m, k, (n + 1 : U32))

def group(+f: String, items: List<&2, Model.Item>, +m: Map<&2, U32>) -> Map<&2, U32>:
  match items:
    case Nil{}:
      m
    case Con{it, t}:
      +k = cell(f, it)
      group(f, t, group.one(Map.get(U32, 0, m, k), k))

def cnts(kvs: List<&2, Sigma<&2, &2, String, _ => U32>>) -> List<&2, Cnt>:
  match kvs:
    case Nil{}:
      []
    case Con{Tuple{k, v}, t}:
      Cnt{k, v} <> cnts(t)

# Biggest group first, ties by key.
def le.cnt(a: Cnt, b: Cnt) -> Bool:
  Cnt{+ka, +na} = a
  Cnt{+kb, +nb} = b
  Bool.or(U32.is_gt(na, nb), Bool.and(U32.is_eq(na, nb), String.is_le(ka, kb)))

def cnt.rows(cs: List<&2, Cnt>) -> List<&2, Format.Row>:
  match cs:
    case Nil{}:
      []
    case Con{c, t}:
      Cnt{k, n} = c
      Format.Row{[k, U32.show(n)]} <> cnt.rows(t)

# (key, count) rows for the field, biggest first.
def count.rows(+f: String, items: List<&2, Model.Item>) -> List<&2, Format.Row>:
  cnt.rows(List.sort(~Cnt, ~le.cnt, cnts(Map.to_list(&2, U32, group(f, items, Map.new(&2, U32))))))
