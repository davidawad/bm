# The bookmark DB file: a JSON array with one item object per line, so git diffs show one bookmark per changed line.
import Base
import bend-kit-json@0.6.1.1/json.bend as Json
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import ./model.bend as Model
import ./chromium.bend as Chromium

def lit(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def field(+k: String, +v: String) -> Bytes.Bytes & Json.Val:
  (lit(k), Json.Str{lit(v)})

def encode.item(item: Model.Item) -> Bytes.Bytes:
  Model.Item{folder, title, url, added} = item
  Json.encode.bytes(Json.Obj{[field("folder", folder), field("title", title), field("url", url), field("added", added)]})

# Each piece after the first is preceded by a comma and newline.
def separate(pieces: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match pieces:
    case Nil{}:
      []
    case Con{p, t}:
      lit(",\n") <> p <> separate(t)

def pieces(items: List<&2, Model.Item>) -> List<&1, Bytes.Bytes>:
  match items:
    case Nil{}:
      []
    case Con{it, t}:
      encode.item(it) <> pieces(t)

def first.piece(ps: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match ps:
    case Nil{}:
      []
    case Con{h, t}:
      h <> separate(t)

def encode(items: List<&2, Model.Item>) -> Bytes.Bytes:
  Bytes.concat(lit("[\n") <> List.append(&1, Bytes.Bytes, first.piece(pieces(items)), [lit("\n]\n")]))

def dec.put(is_folder: Bool, is_title: Bool, is_url: Bool, is_added: Bool, v: Json.Val, it: Model.Item) -> Model.Item:
  match is_folder:
    case True{}:
      Model.Item{folder, title, url, added} = it
      Model.Item{Chromium.val.str(v), title, url, added}
    case False{}:
      match is_title:
        case True{}:
          Model.Item{folder, title, url, added} = it
          Model.Item{folder, Chromium.val.str(v), url, added}
        case False{}:
          match is_url:
            case True{}:
              Model.Item{folder, title, url, added} = it
              Model.Item{folder, title, Chromium.val.str(v), added}
            case False{}:
              match is_added:
                case True{}:
                  Model.Item{folder, title, url, added} = it
                  Model.Item{folder, title, url, Chromium.val.str(v)}
                case False{}:
                  it

def dec.fold(kvs: List<&1, Bytes.Bytes & Json.Val>, it: Model.Item) -> Model.Item:
  match kvs:
    case Nil{}:
      it
    case Con{kv, t}:
      (k, v) = kv
      +key = Bytes.to_string(k)
      dec.fold(t, dec.put(String.eq(key, "folder"), String.eq(key, "title"), String.eq(key, "url"), String.eq(key, "added"), v, it))

def dec.items(vals: List<&1, Json.Val>) -> List<&2, Model.Item>:
  match vals:
    case Nil{}:
      []
    case Con{v, t}:
      dec.fold(Chromium.val.kvs(v), Model.Item{"", "", "", "0"}) <> dec.items(t)

def decode.arr(v: Json.Val) -> Maybe<&1, List<&2, Model.Item>>:
  match v:
    case Json.Arr{xs}:
      Some{dec.items(xs)}
    case _:
      None{}

def decode.parsed(m: Maybe<&1, Json.Val>) -> Maybe<&1, List<&2, Model.Item>>:
  match m:
    case Some{v}:
      decode.arr(v)
    case None{}:
      None{}

# None if the bytes are not a DB file.
def decode(b: Bytes.Bytes) -> Maybe<&1, List<&2, Model.Item>>:
  decode.parsed(Json.parse.bytes(b))
