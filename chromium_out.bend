# Items -> Chromium-family `Bookmarks` JSON, nested by folder path. Folders appear in sorted path order.
import Base
import bend-kit-json@0.6.1.1/json.bend as Json
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import ./model.bend as Model
import ./paths.bend as Paths

# Output so far (newest piece first), per-level "already has an element" flags (deepest first), the open folder path, next id.
type Em is Type:
  Em{out: List<&1, Bytes.Bytes>, flags: List<&2, Bool>, cur: List<&2, String>, id: Nat}

def lit(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def js(+s: String) -> Bytes.Bytes:
  Json.encode.bytes(Json.Str{Bytes.from_string(s)})

def comma(has: Bool) -> Bytes.Bytes:
  Bool.pick(Bytes.Bytes, has, lit(","), lit(""))

def head.flag(flags: List<&2, Bool>) -> Bool:
  match flags:
    case Nil{}:
      False{}
    case Con{f, t}:
      f

def mark(flags: List<&2, Bool>) -> List<&2, Bool>:
  match flags:
    case Nil{}:
      [True{}]
    case Con{f, t}:
      True{} <> t

def pad12(+s: String) -> String:
  String.concat([String.repeat("0", Nat.sub(12n, String.length(s))), s])

def guid(id: Nat) -> String:
  String.concat(["00000000-0000-4000-8000-", pad12(Nat.show(id))])

def ident(+id: Nat) -> Bytes.Bytes:
  Bytes.concat([lit(",\"id\":\""), lit(Nat.show(id)), lit("\",\"guid\":\""), lit(guid(id)), lit("\"")])

def open.folder(+name: String, em: Em) -> Em:
  Em{out, +flags, +cur, +id} = em
  piece = Bytes.concat([comma(head.flag(flags)), lit("{\"type\":\"folder\",\"name\":"), js(name), ident(id), lit(",\"date_added\":\"0\",\"date_modified\":\"0\",\"children\":[")])
  Em{piece <> out, False{} <> mark(flags), List.append(&2, String, cur, [name]), 1n+id}

def open.all(segs: List<&2, String>, em: Em) -> Em:
  match segs:
    case Nil{}:
      em
    case Con{s, t}:
      open.all(t, open.folder(s, em))

def close.one(em: Em) -> Em:
  Em{out, flags, +cur, id} = em
  Em{lit("]}") <> out, mark(List.tail(&2, Bool, flags)), List.take(&2, String, cur, Nat.sub(List.length(&2, String, cur), 1n)), id}

def close.n(n: Nat, em: Em) -> Em:
  match n:
    case 0n:
      em
    case 1n+p:
      close.n(p, close.one(em))

def add.url(item: Model.Item, em: Em) -> Em:
  Model.Item{folder, title, url, added} = item
  Em{out, +flags, cur, +id} = em
  piece = Bytes.concat([comma(head.flag(flags)), lit("{\"type\":\"url\",\"name\":"), js(title), ident(id), lit(",\"date_added\":"), js(added), lit(",\"url\":"), js(url), lit("}")])
  Em{piece <> out, mark(flags), cur, 1n+id}

def place.go(item: Model.Item, em: Em, d: Nat & List<&2, String>) -> Em:
  match d:
    case (n, rest):
      add.url(item, open.all(rest, close.n(n, em)))

def place(+item: Model.Item, em: Em) -> Em:
  Model.Item{+folder, title, url, added} = item
  Em{out, flags, +cur, id} = em
  place.go(item, Em{out, flags, cur, id}, Paths.diff(cur, Paths.tail(Paths.split(folder))))

def emit.items(items: List<&2, Model.Item>, em: Em) -> Em:
  match items:
    case Nil{}:
      em
    case Con{it, t}:
      emit.items(t, place(it, em))

def le.folder(a: Model.Item, b: Model.Item) -> Bool:
  Model.Item{fa, ta, ua, aa} = a
  Model.Item{fb, tb, ub, ab} = b
  String.is_le(fa, fb)

def first(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{r, t}:
      r

def root.of(+item: Model.Item) -> String:
  Model.Item{+folder, title, url, added} = item
  first(Paths.split(folder))

def only.keep(keep: Bool, it: Model.Item, rest: List<&2, Model.Item>) -> List<&2, Model.Item>:
  match keep:
    case True{}:
      it <> rest
    case False{}:
      rest

def only(+key: String, items: List<&2, Model.Item>) -> List<&2, Model.Item>:
  match items:
    case Nil{}:
      Nil{}
    case Con{+it, t}:
      only.keep(String.eq(root.of(it), key), it, only(key, t))

def root.open(key: String, name: String, em: Em) -> Em:
  Em{out, +flags, cur, +id} = em
  piece = Bytes.concat([comma(head.flag(flags)), js(key), lit(":{\"type\":\"folder\",\"name\":"), js(name), ident(id), lit(",\"date_added\":\"0\",\"date_modified\":\"0\",\"children\":[")])
  Em{piece <> out, False{} <> mark(flags), [], 1n+id}

def root.close(em: Em) -> Em:
  Em{out, flags, +cur, id} = em
  close.n(List.length(&2, String, cur), Em{out, flags, cur, id})

def root.shut(em: Em) -> Em:
  Em{out, flags, cur, id} = em
  Em{lit("]}") <> out, mark(List.tail(&2, Bool, flags)), cur, id}

# One root: its items (already sorted), then every open folder closed.
def root.body(+key: String, name: String, items: List<&2, Model.Item>, em: Em) -> Em:
  root.shut(root.close(emit.items(only(key, items), root.open(key, name, em))))

def render.em(em: Em) -> Bytes.Bytes:
  Em{out, flags, cur, id} = em
  Bytes.concat(List.reverse(&1, Bytes.Bytes, lit("}}") <> out))

# The complete file. Chromium regenerates `checksum` when it is absent.
def render.sorted(+items: List<&2, Model.Item>) -> Bytes.Bytes:
  render.em(root.body("synced", "Mobile bookmarks", items, root.body("other", "Other bookmarks", items, root.body("bookmark_bar", "Bookmarks bar", items, Em{[lit("{\"version\":1,\"roots\":{")], [False{}], [], 1n}))))

def render(items: List<&2, Model.Item>) -> Bytes.Bytes:
  render.sorted(List.sort(~Model.Item, ~le.folder, items))
