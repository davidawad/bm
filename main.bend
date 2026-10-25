# bm: browser-independent bookmark store. Command dispatch; see README.md.
import Base
import ./cli.bend as Cli
import ./cmd.bend as Cmd
import ./config.bend as Config
import ./cmdq.bend as Cmdq

def usage() -> String:
  "usage: bm [--db PATH] [--config PATH] <command>   (DB default ~/.local/share/bm/bm.json, or $BM_DB)\n pull <browser> [--path P] [--dry-run]   merge a browser's bookmarks into the DB (Safari: needs Full Disk Access)\n  push <browser> [--path P]               write the DB as that browser's Bookmarks file\n  export-html [--out P]                   Netscape HTML (Safari, Firefox and others import it)\n  tree [--depth N]                        folders with counts\n  find <text>                             search titles and URLs\n  add <url> [--title T] [--folder F]      add a bookmark (default folder bookmark_bar/Inbox)\n  mv <url-text> <folder>                  move matching bookmarks\n  rm <url-text>                           delete matching bookmarks\n  classify [--apply] [--min N]            suggest a folder for every Inbox bookmark (word and host scores)\n  classify --llm \"CMD ARGS\"              file Inbox bookmarks with an LLM command that reads a prompt on stdin\n  eval [--every K] [--min N]              hold out every K-th bookmark and score the classifier\n  ls | export [filters] [--format F]      list bookmarks (ls: table, export: json); F = table tsv csv json jsonl toon md html urls\n  count --by FIELD [filters]              group and count (folder host root year month depth)\n  stats                                   totals, folders, hosts, inbox, duplicates, date range\nfilters: --folder PATH --host H --text T --since YYYY-MM-DD --until YYYY-MM-DD --dupes; shaping: --sort FIELD --reverse --limit N --fields a,b --out FILE\nbrowsers: chrome helium brave edge browseros (pull and push), safari (pull only), file (with --path)"

def q3(is_stats: Bool, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_stats:
    case True{}:
      Cmdq.stats(args, db, cfg)
    case False{}:
      IO.die(Unit, 2, usage())

def q2(is_count: Bool, is_stats: Bool, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_count:
    case True{}:
      Cmdq.count(args, db)
    case False{}:
      q3(is_stats, args, db, cfg)

def q1(is_export: Bool, is_count: Bool, is_stats: Bool, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_export:
    case True{}:
      Cmdq.ls(args, db, "json")
    case False{}:
      q2(is_count, is_stats, args, db, cfg)

def q0(is_ls: Bool, is_export: Bool, is_count: Bool, is_stats: Bool, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_ls:
    case True{}:
      Cmdq.ls(args, db, "table")
    case False{}:
      q1(is_export, is_count, is_stats, args, db, cfg)

def q(+c: String, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  q0(String.eq(c, "ls"), String.eq(c, "export"), String.eq(c, "count"), String.eq(c, "stats"), args, db, cfg)

def d9(is_eval: Bool, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_eval:
    case True{}:
      Cmd.eval(args, db, cfg)
    case False{}:
      q(Cli.nth(Cli.pos(args), 0n), args, db, cfg)

def d8(is_classify: Bool, is_eval: Bool, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_classify:
    case True{}:
      Cmd.classify(args, db, cfg)
    case False{}:
      d9(is_eval, args, db, cfg)

def d7(is_add: Bool, is_classify: Bool, is_eval: Bool, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_add:
    case True{}:
      Cmd.add(args, db, cfg)
    case False{}:
      d8(is_classify, is_eval, args, db, cfg)

def d6(is_rm: Bool, is_add: Bool, is_classify: Bool, is_eval: Bool, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_rm:
    case True{}:
      Cmd.rm(args, db)
    case False{}:
      d7(is_add, is_classify, is_eval, args, db, cfg)

def d5(is_mv: Bool, is_rm: Bool, is_add: Bool, is_classify: Bool, is_eval: Bool, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_mv:
    case True{}:
      Cmd.mv(args, db)
    case False{}:
      d6(is_rm, is_add, is_classify, is_eval, args, db, cfg)

def d4(is_find: Bool, is_mv: Bool, is_rm: Bool, is_add: Bool, is_classify: Bool, is_eval: Bool, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_find:
    case True{}:
      Cmd.find(args, db)
    case False{}:
      d5(is_mv, is_rm, is_add, is_classify, is_eval, args, db, cfg)

def d3(is_tree: Bool, is_find: Bool, is_mv: Bool, is_rm: Bool, is_add: Bool, is_classify: Bool, is_eval: Bool, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_tree:
    case True{}:
      Cmd.tree(args, db)
    case False{}:
      d4(is_find, is_mv, is_rm, is_add, is_classify, is_eval, args, db, cfg)

def d2(is_html: Bool, is_tree: Bool, is_find: Bool, is_mv: Bool, is_rm: Bool, is_add: Bool, is_classify: Bool, is_eval: Bool, +args: List<&2, String>, +db: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_html:
    case True{}:
      Cmd.export.html(args, db)
    case False{}:
      d3(is_tree, is_find, is_mv, is_rm, is_add, is_classify, is_eval, args, db, cfg)

def d1(is_push: Bool, is_html: Bool, is_tree: Bool, is_find: Bool, is_mv: Bool, is_rm: Bool, is_add: Bool, is_classify: Bool, is_eval: Bool, +args: List<&2, String>, +db: String, +home: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_push:
    case True{}:
      Cmd.push(args, db, home)
    case False{}:
      d2(is_html, is_tree, is_find, is_mv, is_rm, is_add, is_classify, is_eval, args, db, cfg)

def d0(is_pull: Bool, is_push: Bool, is_html: Bool, is_tree: Bool, is_find: Bool, is_mv: Bool, is_rm: Bool, is_add: Bool, is_classify: Bool, is_eval: Bool, +args: List<&2, String>, +db: String, +home: String, +cfg: Config.Cfg) -> IO(Unit):
  match is_pull:
    case True{}:
      Cmd.pull(args, db, home, cfg)
    case False{}:
      d1(is_push, is_html, is_tree, is_find, is_mv, is_rm, is_add, is_classify, is_eval, args, db, home, cfg)

def dispatch(+args: List<&2, String>, +db: String, +home: String, +cfg: Config.Cfg) -> IO(Unit):
  +c = Cli.nth(Cli.pos(args), 0n)
  d0(String.eq(c, "pull"), String.eq(c, "push"), String.eq(c, "export-html"), String.eq(c, "tree"), String.eq(c, "find"), String.eq(c, "mv"), String.eq(c, "rm"), String.eq(c, "add"), String.eq(c, "classify"), String.eq(c, "eval"), args, db, home, cfg)

def env.or(+d: String, env: Result<&1, &1, U32 & String, String>) -> String:
  match env:
    case Done{p}:
      p
    case Fail{e}:
      d

def db.path(+home: String, +over: Maybe<&2, String>, env: Result<&1, &1, U32 & String, String>) -> String:
  match over:
    case Some{p}:
      p
    case None{}:
      env.or(String.append(home, "/.local/share/bm/bm.json"), env)

# --config beats $BM_CONFIG beats <db>.config.json next to the DB.
def cfg.path(+db: String, +over: Maybe<&2, String>, env: Result<&1, &1, U32 & String, String>) -> String:
  match over:
    case Some{p}:
      p
    case None{}:
      env.or(Config.default.path(db), env)

def go.cfg(+args: List<&2, String>, +home: String, +db: String, cfg: Config.Cfg) -> IO(Unit):
  dispatch(args, db, home, cfg)

def go.load(+args: List<&2, String>, +home: String, +db: String, +cfgpath: String) -> IO(Unit):
  do IO<Unit>:
    cfg : Config.Cfg <- Config.load(cfgpath)
    go.cfg(args, home, db, cfg)

def go.paths(+args: List<&2, String>, +home: String, +db: String, envcfg: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  go.load(args, home, db, cfg.path(db, Cli.opt(args, "--config"), envcfg))

def go(+args: List<&2, String>, +home: String, env: Result<&1, &1, U32 & String, String>, envcfg: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  go.paths(args, home, db.path(home, Cli.opt(args, "--db"), env), envcfg)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    home : String <- IO.try(String, IO.get_env("HOME"))
    env : Result<&1, &1, U32 & String, String> <- IO.get_env("BM_DB")
    envcfg : Result<&1, &1, U32 & String, String> <- IO.get_env("BM_CONFIG")
    go(List.tail(&2, String, Cli.copy(args)), home, env, envcfg)
