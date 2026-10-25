# User configuration (JSON). Everything is optional; the defaults reproduce bm without a config file.
#
# {
#   "inbox": "bookmark_bar/Inbox",          where unfiled bookmarks wait
#   "min_score": 300,                       classifier confidence needed to move a bookmark (--min overrides)
#   "llm": "claude -p --model claude-haiku-5-5 --no-session-persistence",   when set, classify files Inbox bookmarks with it
#   "folders": [                            your folder structure, usable before any bookmark is filed there
#     { "path": "bookmark_bar/Dev/AI", "description": "LLM tools, papers and APIs",
#       "words": ["llm", "gpt"], "hosts": ["huggingface.co"], "strict": false }
#   ]
# }
#
# A folder's words and hosts act as bookmarks already filed there (soft hints). With "strict": true, any bookmark whose
# title or URL has one of the words, or whose host is (a subdomain of) one of the hosts, goes to that folder outright.
import Base
import bend-kit-json@0.6.1.1/json.bend as Json
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-kit-files@0.2.0.0/files.bend as Fs
import ./io.bend as Io
import ./chromium.bend as Chromium

type Fh is Data:
  Fh{path: String, desc: String, hosts: List<&2, String>, words: List<&2, String>, strict: Bool}

type Cfg is Data:
  Cfg{inbox: String, min: U32, llm: String, folders: List<&2, Fh>}

def default() -> Cfg:
  Cfg{"bookmark_bar/Inbox", 300, "", []}

def val.flag(v: Json.Val) -> Bool:
  match v:
    case Json.Flag{on}:
      on
    case _:
      False{}

def val.num(v: Json.Val) -> String:
  match v:
    case Json.Num{s}:
      Bytes.to_string(s)
    case _:
      ""

def strs(vals: List<&1, Json.Val>) -> List<&2, String>:
  match vals:
    case Nil{}:
      []
    case Con{v, t}:
      Chromium.val.str(v) <> strs(t)

def fh.put.b(is_hosts: Bool, is_words: Bool, is_strict: Bool, v: Json.Val, fh: Fh) -> Fh:
  match is_hosts:
    case True{}:
      Fh{path, desc, hosts, words, strict} = fh
      Fh{path, desc, strs(Chromium.val.kids(v)), words, strict}
    case False{}:
      match is_words:
        case True{}:
          Fh{path, desc, hosts, words, strict} = fh
          Fh{path, desc, hosts, strs(Chromium.val.kids(v)), strict}
        case False{}:
          match is_strict:
            case True{}:
              Fh{path, desc, hosts, words, strict} = fh
              Fh{path, desc, hosts, words, val.flag(v)}
            case False{}:
              fh

def fh.put(is_path: Bool, is_desc: Bool, is_hosts: Bool, is_words: Bool, is_strict: Bool, v: Json.Val, fh: Fh) -> Fh:
  match is_path:
    case True{}:
      Fh{path, desc, hosts, words, strict} = fh
      Fh{Chromium.val.str(v), desc, hosts, words, strict}
    case False{}:
      match is_desc:
        case True{}:
          Fh{path, desc, hosts, words, strict} = fh
          Fh{path, Chromium.val.str(v), hosts, words, strict}
        case False{}:
          fh.put.b(is_hosts, is_words, is_strict, v, fh)

def fh.fold(kvs: List<&1, Bytes.Bytes & Json.Val>, fh: Fh) -> Fh:
  match kvs:
    case Nil{}:
      fh
    case Con{kv, t}:
      (k, v) = kv
      +key = Bytes.to_string(k)
      fh.fold(t, fh.put(String.eq(key, "path"), String.eq(key, "description"), String.eq(key, "hosts"), String.eq(key, "words"), String.eq(key, "strict"), v, fh))

def fhs(vals: List<&1, Json.Val>) -> List<&2, Fh>:
  match vals:
    case Nil{}:
      []
    case Con{v, t}:
      fh.fold(Chromium.val.kvs(v), Fh{"", "", [], [], False{}}) <> fhs(t)

def cfg.put.b(is_llm: Bool, is_folders: Bool, v: Json.Val, cfg: Cfg) -> Cfg:
  match is_llm:
    case True{}:
      Cfg{inbox, min, llm, folders} = cfg
      Cfg{inbox, min, Chromium.val.str(v), folders}
    case False{}:
      match is_folders:
        case True{}:
          Cfg{inbox, min, llm, folders} = cfg
          Cfg{inbox, min, llm, fhs(Chromium.val.kids(v))}
        case False{}:
          cfg

def cfg.put(is_inbox: Bool, is_min: Bool, is_llm: Bool, is_folders: Bool, v: Json.Val, cfg: Cfg) -> Cfg:
  match is_inbox:
    case True{}:
      Cfg{inbox, min, llm, folders} = cfg
      Cfg{Chromium.val.str(v), min, llm, folders}
    case False{}:
      match is_min:
        case True{}:
          Cfg{inbox, min, llm, folders} = cfg
          Cfg{inbox, Maybe.default(&2, U32, U32.read(val.num(v)), min), llm, folders}
        case False{}:
          cfg.put.b(is_llm, is_folders, v, cfg)

def cfg.fold(kvs: List<&1, Bytes.Bytes & Json.Val>, cfg: Cfg) -> Cfg:
  match kvs:
    case Nil{}:
      cfg
    case Con{kv, t}:
      (k, v) = kv
      +key = Bytes.to_string(k)
      cfg.fold(t, cfg.put(String.eq(key, "inbox"), String.eq(key, "min_score"), String.eq(key, "llm"), String.eq(key, "folders"), v, cfg))

def parsed(m: Maybe<&1, Json.Val>) -> Cfg:
  match m:
    case Some{v}:
      cfg.fold(Chromium.val.kvs(v), default())
    case None{}:
      default()

def parse(b: Bytes.Bytes) -> Cfg:
  parsed(Json.parse.bytes(b))

def loaded(path: String, there: Bool) -> IO(Cfg):
  match there:
    case False{}:
      IO.pure(Cfg, default())
    case True{}:
      do IO<Cfg>:
        b : Bytes.Bytes <- Io.read.file(path)
        IO.pure(Cfg, parse(b))

# A missing config file is the default configuration.
def load(+path: String) -> IO(Cfg):
  do IO<Cfg>:
    there : Bool <- Fs.exists(path)
    loaded(path, there)

# Default config path: next to the DB, bm.json -> bm.config.json.
def default.path(+db: String) -> String:
  String.append(Bool.pick(String, String.ends_with(db, ".json"), String.take(db, Nat.sub(String.length(db), 5n)), db), ".config.json")

# Accessors (a Cfg is Data, so each can be called on the same config).
def inbox.of(+cfg: Cfg) -> String:
  Cfg{inbox, min, llm, folders} = cfg
  inbox

def min.of(+cfg: Cfg) -> U32:
  Cfg{inbox, min, llm, folders} = cfg
  min

def llm.of(+cfg: Cfg) -> String:
  Cfg{inbox, min, llm, folders} = cfg
  llm

def folders.of(+cfg: Cfg) -> List<&2, Fh>:
  Cfg{inbox, min, llm, folders} = cfg
  folders
