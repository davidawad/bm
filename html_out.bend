# Items -> Netscape bookmark HTML, the one format every browser imports. Folders appear in sorted path order.
import Base
import ./model.bend as Model
import ./paths.bend as Paths

# Output so far (newest piece first) and the open folder path.
type Em is Data:
  Em{out: List<&2, String>, cur: List<&2, String>}

def esc.code(+code: U32) -> String:
  Bool.pick(String, U32.is_eq(code, 38), "&amp;", Bool.pick(String, U32.is_eq(code, 60), "&lt;", Bool.pick(String, U32.is_eq(code, 62), "&gt;", Bool.pick(String, U32.is_eq(code, 34), "&quot;", String.from_list([Chr{code}])))))

def esc.char(c: Char) -> String:
  match c:
    case Chr{code}:
      esc.code(code)

def esc(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{c, t}:
      String.append(esc.char(c), esc(t))

def close.one(em: Em) -> Em:
  Em{out, +cur} = em
  Em{"</DL><p>\n" <> out, List.take(&2, String, cur, Nat.sub(List.length(&2, String, cur), 1n))}

def close.n(n: Nat, em: Em) -> Em:
  match n:
    case 0n:
      em
    case 1n+p:
      close.n(p, close.one(em))

def open.folder(+name: String, em: Em) -> Em:
  Em{out, cur} = em
  Em{String.concat(["<DT><H3>", esc(name), "</H3>\n<DL><p>\n"]) <> out, List.append(&2, String, cur, [name])}

def open.all(segs: List<&2, String>, em: Em) -> Em:
  match segs:
    case Nil{}:
      em
    case Con{s, t}:
      open.all(t, open.folder(s, em))

def add.url(item: Model.Item, em: Em) -> Em:
  Model.Item{folder, title, url, added} = item
  Em{out, cur} = em
  Em{String.concat(["<DT><A HREF=\"", esc(url), "\">", esc(title), "</A>\n"]) <> out, cur}

def place.go(item: Model.Item, em: Em, d: Nat & List<&2, String>) -> Em:
  match d:
    case (n, rest):
      add.url(item, open.all(rest, close.n(n, em)))

def place(+item: Model.Item, em: Em) -> Em:
  Model.Item{+folder, title, url, added} = item
  Em{out, +cur} = em
  place.go(item, Em{out, cur}, Paths.diff(cur, Paths.split(folder)))

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

def close.all(em: Em) -> Em:
  Em{out, +cur} = em
  close.n(List.length(&2, String, cur), Em{out, cur})

def finish(em: Em) -> String:
  Em{out, cur} = em
  String.concat(List.reverse(&2, String, "</DL><p>\n" <> out))

def render(items: List<&2, Model.Item>) -> String:
  finish(close.all(emit.items(List.sort(~Model.Item, ~le.folder, items), Em{["<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">\n<TITLE>Bookmarks</TITLE>\n<H1>Bookmarks</H1>\n<DL><p>\n"], []})))
