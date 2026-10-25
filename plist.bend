# XML property lists (`plutil -convert xml1`) -> Json.Val. Binary plists carry Data and Date values that JSON cannot hold,
# so plutil's own JSON conversion fails on Safari's file; this reads the XML form and keeps the structure.
import Base
import bend-kit-json@0.6.1.1/json.bend as Json
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes

# An open dict (fields so far, newest first, and the key waiting for its value) or array (items so far, newest first).
type Fr is Type:
  FObj{kvs: List<&1, Bytes.Bytes & Json.Val>, key: Bytes.Bytes}
  FArr{xs: List<&1, Json.Val>}

type St is Type:
  St{stack: List<&1, Fr>, root: Maybe<&1, Json.Val>}

# What a tag does.
type K is Data:
  KDictOpen{}
  KDictClose{}
  KArrOpen{}
  KArrClose{}
  KKey{}
  KStr{}
  KNum{}
  KData{}
  KTrue{}
  KFalse{}
  KEmptyDict{}
  KEmptyArr{}
  KEmptyStr{}
  KSkip{}

def kind(+t: String) -> K:
  Bool.pick(K, String.eq(t, "dict"), KDictOpen{},
  Bool.pick(K, String.eq(t, "/dict"), KDictClose{},
  Bool.pick(K, String.eq(t, "array"), KArrOpen{},
  Bool.pick(K, String.eq(t, "/array"), KArrClose{},
  Bool.pick(K, String.eq(t, "key"), KKey{},
  Bool.pick(K, String.eq(t, "string"), KStr{},
  Bool.pick(K, Bool.or(String.eq(t, "integer"), String.eq(t, "real")), KNum{},
  Bool.pick(K, Bool.or(String.eq(t, "data"), String.eq(t, "date")), KData{},
  Bool.pick(K, String.eq(t, "true/"), KTrue{},
  Bool.pick(K, String.eq(t, "false/"), KFalse{},
  Bool.pick(K, String.eq(t, "dict/"), KEmptyDict{},
  Bool.pick(K, String.eq(t, "array/"), KEmptyArr{},
  Bool.pick(K, String.eq(t, "string/"), KEmptyStr{}, KSkip{})))))))))))))

# The five predefined XML entities.
def unesc.piece(+p: String) -> String:
  Bool.pick(String, String.starts_with(p, "amp;"), String.append("&", String.drop(p, 4n)),
  Bool.pick(String, String.starts_with(p, "lt;"), String.append("<", String.drop(p, 3n)),
  Bool.pick(String, String.starts_with(p, "gt;"), String.append(">", String.drop(p, 3n)),
  Bool.pick(String, String.starts_with(p, "quot;"), String.append("\"", String.drop(p, 5n)),
  Bool.pick(String, String.starts_with(p, "apos;"), String.append("'", String.drop(p, 5n)), String.append("&", p))))))

def unesc.rest(ps: List<&2, String>) -> List<&2, String>:
  match ps:
    case Nil{}:
      []
    case Con{p, t}:
      unesc.piece(p) <> unesc.rest(t)

def unesc.parts(ps: List<&2, String>) -> String:
  match ps:
    case Nil{}:
      ""
    case Con{h, t}:
      String.append(h, String.concat(unesc.rest(t)))

def unesc(s: String) -> String:
  unesc.parts(String.split(s, '&'))

def add.into(v: Json.Val, fr: Fr, rest: List<&1, Fr>, root: Maybe<&1, Json.Val>) -> St:
  match fr:
    case FArr{xs}:
      St{FArr{v <> xs} <> rest, root}
    case FObj{kvs, key}:
      St{FObj{(key, v) <> kvs, Bytes.from_string("")} <> rest, root}

def add.top(v: Json.Val, stack: List<&1, Fr>, root: Maybe<&1, Json.Val>) -> St:
  match stack:
    case Nil{}:
      St{[], Some{v}}
    case Con{fr, rest}:
      add.into(v, fr, rest, root)

# Attach a finished value to the open container, or make it the root.
def add.val(v: Json.Val, st: St) -> St:
  St{stack, root} = st
  add.top(v, stack, root)

def push(fr: Fr, st: St) -> St:
  St{stack, root} = st
  St{fr <> stack, root}

def finish(fr: Fr) -> Json.Val:
  match fr:
    case FArr{xs}:
      Json.Arr{List.reverse(&1, Json.Val, xs)}
    case FObj{kvs, key}:
      Json.Obj{List.reverse(&1, Bytes.Bytes & Json.Val, kvs)}

def close.top(stack: List<&1, Fr>, root: Maybe<&1, Json.Val>) -> St:
  match stack:
    case Nil{}:
      St{[], root}
    case Con{fr, rest}:
      add.top(finish(fr), rest, root)

def close(st: St) -> St:
  St{stack, root} = st
  close.top(stack, root)

def set.key.into(fr: Fr, rest: List<&1, Fr>, k: Bytes.Bytes) -> List<&1, Fr>:
  match fr:
    case FObj{kvs, key}:
      FObj{kvs, k} <> rest
    case FArr{xs}:
      FArr{xs} <> rest

def set.key.top(stack: List<&1, Fr>, k: Bytes.Bytes) -> List<&1, Fr>:
  match stack:
    case Nil{}:
      []
    case Con{fr, rest}:
      set.key.into(fr, rest, k)

def set.key(k: String, st: St) -> St:
  St{stack, root} = st
  St{set.key.top(stack, Bytes.from_string(unesc(k))), root}

# Apply one `tag>text` chunk (the document split at every "<").
def apply(k: K, text: String, st: St) -> St:
  match k:
    case KDictOpen{}:
      push(FObj{[], Bytes.from_string("")}, st)
    case KDictClose{}:
      close(st)
    case KArrOpen{}:
      push(FArr{[]}, st)
    case KArrClose{}:
      close(st)
    case KKey{}:
      set.key(text, st)
    case KStr{}:
      add.val(Json.Str{Bytes.from_string(unesc(text))}, st)
    case KNum{}:
      add.val(Json.Num{Bytes.from_string(text)}, st)
    case KData{}:
      add.val(Json.Null{}, st)
    case KTrue{}:
      add.val(Json.Flag{True{}}, st)
    case KFalse{}:
      add.val(Json.Flag{False{}}, st)
    case KEmptyDict{}:
      add.val(Json.Obj{[]}, st)
    case KEmptyArr{}:
      add.val(Json.Arr{[]}, st)
    case KEmptyStr{}:
      add.val(Json.Str{Bytes.from_string("")}, st)
    case KSkip{}:
      st

# `tag>text` -> (tag, text); text keeps any further ">".
def chunk.parts(ps: List<&2, String>) -> String & String:
  match ps:
    case Nil{}:
      ("", "")
    case Con{tag, rest}:
      (tag, String.join(rest, ">"))

def chunk(c: String) -> String & String:
  chunk.parts(String.split(c, '>'))

def step(c: String & String, st: St) -> St:
  match c:
    case (tag, text):
      apply(kind(tag), text, st)

def run(chunks: List<&2, String>, st: St) -> St:
  match chunks:
    case Nil{}:
      st
    case Con{c, t}:
      run(t, step(chunk(c), st))

def root.of(st: St) -> Maybe<&1, Json.Val>:
  St{stack, root} = st
  root

# The document's top value; None when the text holds no value.
def parse(xml: String) -> Maybe<&1, Json.Val>:
  root.of(run(String.split(xml, '<'), St{[], None{}}))
