# Chromium-family `Bookmarks` JSON (Chrome, Helium, Brave, Edge, BrowserOS): read into Items.
import Base
import bend-kit-json@0.6.1.1/json.bend as Json
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import ./model.bend as Model

# One node of the tree still to visit, with the path of the folder holding it.
type Fr is Type:
  Fr{path: String, node: Json.Val}

# Key and value names that mark bookmarks in a file format. Chromium and Safari use different ones.
type Keys is Data:
  Keys{ty: String, name: String, url: String, added: String, kids: String, uri: String, url_val: String, folder_val: String, safari: Bool}

def keys.chromium() -> Keys:
  Keys{"type", "name", "url", "date_added", "children", "", "url", "folder", False{}}

def keys.safari() -> Keys:
  Keys{"WebBookmarkType", "Title", "URLString", "", "Children", "URIDictionary", "WebBookmarkTypeLeaf", "WebBookmarkTypeList", True{}}

# The fields of a bookmark or folder object that matter here.
type Fx is Type:
  Fx{ty: String, name: String, url: String, added: String, kids: List<&1, Json.Val>}

def val.str(v: Json.Val) -> String:
  match v:
    case Json.Str{s}:
      Bytes.to_string(s)
    case _:
      ""

def val.kids(v: Json.Val) -> List<&1, Json.Val>:
  match v:
    case Json.Arr{xs}:
      xs
    case _:
      []

def val.kvs(v: Json.Val) -> List<&1, Bytes.Bytes & Json.Val>:
  match v:
    case Json.Obj{kvs}:
      kvs
    case _:
      []

def title.fold(kvs: List<&1, Bytes.Bytes & Json.Val>, acc: String) -> String:
  match kvs:
    case Nil{}:
      acc
    case Con{kv, t}:
      (k, v) = kv
      title.fold(t, Bool.pick(String, String.eq(Bytes.to_string(k), "title"), val.str(v), acc))

def val.title(v: Json.Val) -> String:
  title.fold(val.kvs(v), "")

def fx.empty() -> Fx:
  Fx{"", "", "", "0", []}

def fx.kids(fx: Fx) -> List<&1, Json.Val>:
  Fx{ty, name, url, added, kids} = fx
  kids

def fx.put.kids(is_added: Bool, is_kids: Bool, is_uri: Bool, v: Json.Val, fx: Fx) -> Fx:
  match is_added:
    case True{}:
      Fx{ty, name, url, added, kids} = fx
      Fx{ty, name, url, val.str(v), kids}
    case False{}:
      match is_kids:
        case True{}:
          Fx{ty, name, url, added, kids} = fx
          Fx{ty, name, url, added, val.kids(v)}
        case False{}:
          match is_uri:
            case True{}:
              Fx{ty, name, url, added, kids} = fx
              Fx{ty, val.title(v), url, added, kids}
            case False{}:
              fx

def fx.put.url(is_name: Bool, is_url: Bool, is_added: Bool, is_kids: Bool, is_uri: Bool, v: Json.Val, fx: Fx) -> Fx:
  match is_name:
    case True{}:
      Fx{ty, name, url, added, kids} = fx
      Fx{ty, val.str(v), url, added, kids}
    case False{}:
      match is_url:
        case True{}:
          Fx{ty, name, url, added, kids} = fx
          Fx{ty, name, val.str(v), added, kids}
        case False{}:
          fx.put.kids(is_added, is_kids, is_uri, v, fx)

def fx.put(is_ty: Bool, is_name: Bool, is_url: Bool, is_added: Bool, is_kids: Bool, is_uri: Bool, v: Json.Val, fx: Fx) -> Fx:
  match is_ty:
    case True{}:
      Fx{ty, name, url, added, kids} = fx
      Fx{val.str(v), name, url, added, kids}
    case False{}:
      fx.put.url(is_name, is_url, is_added, is_kids, is_uri, v, fx)

def fx.fold(ks: Keys, kvs: List<&1, Bytes.Bytes & Json.Val>, fx: Fx) -> Fx:
  Keys{+kty, +kname, +kurl, +kadded, +kkids, +kuri, +kuv, +kfv, +ksafari} = ks
  match kvs:
    case Nil{}:
      fx
    case Con{kv, t}:
      (k, v) = kv
      +key = Bytes.to_string(k)
      fx.fold(Keys{kty, kname, kurl, kadded, kkids, kuri, kuv, kfv, ksafari}, t, fx.put(String.eq(key, kty), String.eq(key, kname), String.eq(key, kurl), String.eq(key, kadded), String.eq(key, kkids), String.eq(key, kuri), v, fx))

# Children of a folder as stack frames, first child on top.
def frames(+path: String, kids: List<&1, Json.Val>, rest: List<&1, Fr>) -> List<&1, Fr>:
  match kids:
    case Nil{}:
      rest
    case Con{k, t}:
      Fr{path, k} <> frames(path, t, rest)

def join.path(+parent: String, +name: String) -> String:
  String.concat([parent, "/", name])

# Safari names its two real roots BookmarksBar and BookmarksMenu; the DB calls them bookmark_bar and other.
def safari.root(+name: String) -> String:
  Bool.pick(String, String.eq(name, "BookmarksBar"), "bookmark_bar", Bool.pick(String, String.eq(name, "BookmarksMenu"), "other", Bool.pick(String, String.is_empty(name), "", String.append("other/", name))))

def child.path(safari: Bool, +parent: String, +name: String) -> String:
  Bool.pick(String, Bool.and(safari, String.is_empty(parent)), safari.root(name), join.path(parent, name))

# Safari's Reading List is not bookmarks.
def folder.kids(skip: Bool, +path: String, kids: List<&1, Json.Val>, rest: List<&1, Fr>) -> List<&1, Fr>:
  match skip:
    case True{}:
      rest
    case False{}:
      frames(path, kids, rest)

# What a visited node does to the walk, decided from its parsed fields.
def visit.kind(+name: String, +url: String, +added: String, kids: List<&1, Json.Val>, +path: String, +safari: Bool, rest: List<&1, Fr>, acc: List<&2, Model.Item>, is_url: Bool, is_folder: Bool) -> List<&1, Fr> & List<&2, Model.Item>:
  match is_url:
    case True{}:
      (rest, Model.Item{path, name, url, added} <> acc)
    case False{}:
      match is_folder:
        case True{}:
          (folder.kids(Bool.and(safari, String.starts_with(name, "com.apple.ReadingList")), child.path(safari, path, name), kids, rest), acc)
        case False{}:
          (rest, acc)

def visit(ks: Keys, fx: Fx, +path: String, rest: List<&1, Fr>, acc: List<&2, Model.Item>) -> List<&1, Fr> & List<&2, Model.Item>:
  Keys{kty, kname, kurl, kadded, kkids, kuri, +kuv, +kfv, +ksafari} = ks
  Fx{+ty, +name, +url, +added, kids} = fx
  visit.kind(name, url, added, kids, path, ksafari, rest, acc, String.eq(ty, kuv), String.eq(ty, kfv))

# Visit the node on top of the stack.
def visit.fr(+ks: Keys, fr: Fr, rest: List<&1, Fr>, acc: List<&2, Model.Item>) -> List<&1, Fr> & List<&2, Model.Item>:
  Fr{path, node} = fr
  visit(ks, fx.fold(ks, val.kvs(node), fx.empty()), path, rest, acc)

# Depth-first walk with an explicit stack; fuel bounds the number of nodes visited. The state is (stack, items so far).
def walk(fuel: Nat, +ks: Keys, st: List<&1, Fr> & List<&2, Model.Item>) -> List<&2, Model.Item>:
  match fuel:
    case 0n:
      (stack, acc) = st
      acc
    case 1n+p:
      (stack, acc) = st
      match stack:
        case Nil{}:
          acc
        case Con{fr, rest}:
          walk(p, ks, visit.fr(ks, fr, rest, acc))

# `roots` is an object of root folders; each root's children start at the root's key (bookmark_bar, other, synced).
def roots.frames(kvs: List<&1, Bytes.Bytes & Json.Val>, acc: List<&1, Fr>) -> List<&1, Fr>:
  match kvs:
    case Nil{}:
      acc
    case Con{kv, t}:
      (k, v) = kv
      roots.frames(t, frames(Bytes.to_string(k), fx.kids(fx.fold(keys.chromium(), val.kvs(v), fx.empty())), acc))

def roots.of(m: Maybe<&1, Json.Val>) -> List<&1, Fr>:
  match m:
    case Some{r}:
      roots.frames(val.kvs(r), [])
    case None{}:
      []

def read.parsed(m: Maybe<&1, Json.Val>) -> Maybe<&1, List<&2, Model.Item>>:
  match m:
    case None{}:
      None{}
    case Some{v}:
      Some{List.reverse(&2, Model.Item, walk(10000000n, keys.chromium(), (roots.of(Json.get(v, "roots")), [])))}

# All bookmarks in document order; None if the bytes are not a Bookmarks file.
def read(b: Bytes.Bytes) -> Maybe<&1, List<&2, Model.Item>>:
  read.parsed(Json.parse.bytes(b))

# Safari: the parsed plist is one folder object whose children are BookmarksBar, BookmarksMenu, the Reading List.
def read.safari.parsed(m: Maybe<&1, Json.Val>) -> Maybe<&1, List<&2, Model.Item>>:
  match m:
    case None{}:
      None{}
    case Some{v}:
      Some{List.reverse(&2, Model.Item, walk(10000000n, keys.safari(), ([Fr{"", v}], [])))}

def read.safari(v: Maybe<&1, Json.Val>) -> Maybe<&1, List<&2, Model.Item>>:
  read.safari.parsed(v)
