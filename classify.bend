# Folder classifier. Every bookmark already filed votes for its folder with its tokens (title words, URL words, "@host");
# a candidate scores each folder by the weighted votes of its own tokens. Rare tokens and small folders weigh more.
import Base
import ./model.bend as Model
import ./config.bend as Config

# A folder's count for one token, and the folder's size.
type Fc is Data:
  Fc{folder: String, n: U32, size: U32}

# token -> folders voting for it; folder -> bookmark count.
type Ix is Data:
  Ix{idx: Map<&2, List<&2, Fc>>, sz: Map<&2, U32>, strict: List<&2, Config.Fh>}

def alnum(+c: U32) -> Bool:
  Bool.or(Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57)), Bool.and(U32.is_ge(c, 97), U32.is_le(c, 122)))

def stop(+w: String) -> Bool:
  Bool.or(Bool.or(Bool.or(String.eq(w, "the"), String.eq(w, "and")), Bool.or(String.eq(w, "for"), String.eq(w, "com"))), Bool.or(Bool.or(String.eq(w, "www"), String.eq(w, "http")), Bool.or(String.eq(w, "https"), String.eq(w, "html"))))

def push(+cur: String, +acc: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, Bool.and(Nat.is_gt(String.length(cur), 2n), Bool.not(stop(cur))), cur <> acc, acc)

def tok.go(s: String, +cur: String, +acc: List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}:
      push(cur, acc)
    case SCon{Chr{+c}, t}:
      +ok = alnum(c)
      tok.go(t, Bool.pick(String, ok, String.append(cur, String.from_list([Chr{c}])), ""), Bool.pick(List<&2, String>, ok, acc, push(cur, acc)))

def tokenize(s: String) -> List<&2, String>:
  tok.go(String.to_lower(s), "", [])

# Host without "www.", from "scheme://host/...".
def host.of(segs: List<&2, String>) -> String:
  Maybe.default(&2, String, List.get(&2, String, segs, 2n), "")

def strip.www(+h: String) -> String:
  Bool.pick(String, String.starts_with(h, "www."), String.drop(h, 4n), h)

def host(+url: String) -> String:
  strip.www(host.of(String.split(url, '/')))

# Distinct tokens of a bookmark.
def tokens(+title: String, +url: String) -> List<&2, String>:
  Set.to_list(Set.from_list(String.concat(["@", String.to_lower(host(url))]) <> List.append(&2, String, tokenize(title), tokenize(url))))

# Count one more vote for folder in a token's entries.
def bump(+entries: List<&2, Fc>, +folder: String, +size: U32) -> List<&2, Fc>:
  match entries:
    case Nil{}:
      [Fc{folder, 1, size}]
    case Con{fc, t}:
      Fc{+f, +n, +sz} = fc
      Bool.pick(List<&2, Fc>, String.eq(f, folder), Fc{f, (n + 1 : U32), sz} <> t, Fc{f, n, sz} <> bump(t, folder, size))

def vote.one(+token: String, +folder: String, +size: U32, p: Map<&2, List<&2, Fc>> & List<&2, Fc>) -> Map<&2, List<&2, Fc>>:
  match p:
    case (m, entries):
      Map.set(&2, List<&2, Fc>, m, token, bump(entries, folder, size))

def vote(toks: List<&2, String>, +folder: String, +size: U32, idx: Map<&2, List<&2, Fc>>) -> Map<&2, List<&2, Fc>>:
  match toks:
    case Nil{}:
      idx
    case Con{+t, rest}:
      vote(rest, folder, size, vote.one(t, folder, size, Map.get(List<&2, Fc>, [], idx, t)))

def count.one(p: Map<&2, U32> & U32, +folder: String) -> Map<&2, U32>:
  match p:
    case (m, n):
      Map.set(&2, U32, m, folder, (n + 1 : U32))

def count(items: List<&2, Model.Item>, +skip: String, +sz: Map<&2, U32>) -> Map<&2, U32>:
  match items:
    case Nil{}:
      sz
    case Con{it, t}:
      Model.Item{+folder, title, url, added} = it
      count(t, skip, Bool.pick(Map<&2, U32>, String.eq(folder, skip), sz, count.one(Map.get(U32, 0, sz, folder), folder)))

def size.of(p: Map<&2, U32> & U32) -> U32:
  match p:
    case (m, n):
      n

def build.size(+folder: String, +title: String, +url: String, +skip: String, +idx: Map<&2, List<&2, Fc>>, p: Map<&2, U32> & U32, strict: List<&2, Config.Fh>) -> Ix:
  match p:
    case (sz, size):
      Ix{Bool.pick(Map<&2, List<&2, Fc>>, String.eq(folder, skip), idx, vote(tokens(title, url), folder, size, idx)), sz, strict}

def build.item(it: Model.Item, ix: Ix, +skip: String) -> Ix:
  Model.Item{+folder, +title, +url, added} = it
  Ix{idx, sz, +strict} = ix
  build.size(folder, title, url, skip, idx, Map.get(U32, 0, sz, folder), strict)

def build(items: List<&2, Model.Item>, +skip: String, ix: Ix) -> Ix:
  match items:
    case Nil{}:
      ix
    case Con{it, t}:
      build(t, skip, build.item(it, ix, skip))

# Soft hints: a folder's configured words and hosts vote for it as if five bookmarks with those tokens were filed there.
def host.tokens(hosts: List<&2, String>) -> List<&2, String>:
  match hosts:
    case Nil{}:
      []
    case Con{h, t}:
      String.concat(["@", String.to_lower(h)]) <> host.tokens(t)

def lower.all(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      []
    case Con{x, t}:
      String.to_lower(x) <> lower.all(t)

def hint.rep(+n: Nat, +toks: List<&2, String>, +folder: String, +size: U32, idx: Map<&2, List<&2, Fc>>) -> Map<&2, List<&2, Fc>>:
  match n:
    case 0n:
      idx
    case 1n+p:
      hint.rep(p, toks, folder, size, vote(toks, folder, size, idx))

def hints(folders: List<&2, Config.Fh>, idx: Map<&2, List<&2, Fc>>) -> Map<&2, List<&2, Fc>>:
  match folders:
    case Nil{}:
      idx
    case Con{fh, t}:
      Config.Fh{path, desc, +hosts, +words, strict} = fh
      hints(t, hint.rep(5n, List.append(&2, String, lower.all(words), host.tokens(hosts)), path, 5, idx))

def strict.keep(strict: Bool, fh: Config.Fh, rest: List<&2, Config.Fh>) -> List<&2, Config.Fh>:
  match strict:
    case True{}:
      fh <> rest
    case False{}:
      rest

def only.strict(folders: List<&2, Config.Fh>) -> List<&2, Config.Fh>:
  match folders:
    case Nil{}:
      []
    case Con{fh, t}:
      Config.Fh{+path, +desc, +hosts, +words, +strict} = fh
      strict.keep(strict, Config.Fh{path, desc, hosts, words, strict}, only.strict(t))

def index.hinted(ix: Ix, +folders: List<&2, Config.Fh>) -> Ix:
  Ix{idx, sz, strict} = ix
  Ix{hints(folders, idx), sz, only.strict(folders)}

def index(+items: List<&2, Model.Item>, +skip: String, +folders: List<&2, Config.Fh>) -> Ix:
  index.hinted(build(items, skip, Ix{Map.new(&2, List<&2, Fc>), count(items, skip, Map.new(&2, U32)), []}), folders)

# Score contribution of one token's entries: weight * votes * 1000 / (folders sharing the token * (folder size + 3)).
def add.score(p: Map<&2, U32> & U32, +folder: String, +w: U32, +n: U32, +df: U32, +size: U32) -> Map<&2, U32>:
  match p:
    case (m, old):
      Map.set(&2, U32, m, folder, (old + ((((w * n : U32) * 1000 : U32) / (df * (size + 3 : U32) : U32)) : U32) : U32))

def spread(entries: List<&2, Fc>, +w: U32, +df: U32, scores: Map<&2, U32>) -> Map<&2, U32>:
  match entries:
    case Nil{}:
      scores
    case Con{fc, t}:
      Fc{+f, n, size} = fc
      spread(t, w, df, add.score(Map.get(U32, 0, scores, f), f, w, n, df, size))

def token.weight(+t: String) -> U32:
  Bool.pick(U32, String.starts_with(t, "@"), 8, 1)

def score.token(+t: String, p: Map<&2, List<&2, Fc>> & List<&2, Fc>, scores: Map<&2, U32>) -> Map<&2, U32>:
  match p:
    case (m, +entries):
      spread(entries, token.weight(t), U32.from_nat(List.length(&2, Fc, entries)), scores)

def score.all(toks: List<&2, String>, +idx: Map<&2, List<&2, Fc>>, scores: Map<&2, U32>) -> Map<&2, U32>:
  match toks:
    case Nil{}:
      scores
    case Con{+t, rest}:
      score.all(rest, idx, score.token(t, Map.get(List<&2, Fc>, [], idx, t), scores))

type Bst is Data:
  Bst{folder: String, score: U32}

# The best (folder, score) among the scored folders; empty folder and 0 when nothing voted.
def best(+scored: List<&2, Sigma<&2, &2, String, _ => U32>>, +cur: Bst) -> Bst:
  match scored:
    case Nil{}:
      cur
    case Con{Tuple{+k, +v}, t}:
      Bst{+ck, +cv} = cur
      best(t, Bool.pick(Bst, U32.is_gt(v, cv), Bst{k, v}, Bst{ck, cv}))

# A bookmark with the folder the classifier chose for it and that folder's score.
type Cl is Data:
  Cl{item: Model.Item, folder: String, score: U32}

# ---- hierarchical pick: every folder's score also counts for each ancestor path, then walk down from the root while one child holds enough of the score ----

def prefix.add(p: Map<&2, U32> & U32, +path: String, +s: U32) -> Map<&2, U32>:
  match p:
    case (m, old):
      Map.set(&2, U32, m, path, (old + s : U32))

# Add s to the first d segments' path, then the first d-1, ... down to one segment.
def agg.prefixes(+segs: List<&2, String>, +d: Nat, +s: U32, m: Map<&2, U32>) -> Map<&2, U32>:
  match d:
    case 0n:
      m
    case 1n+p:
      agg.prefixes(segs, p, s, prefix.add(Map.get(U32, 0, m, String.join(List.take(&2, String, segs, 1n+p), "/")), String.join(List.take(&2, String, segs, 1n+p), "/"), s))

def agg(+scored: List<&2, Sigma<&2, &2, String, _ => U32>>, m: Map<&2, U32>) -> Map<&2, U32>:
  match scored:
    case Nil{}:
      m
    case Con{Tuple{+k, +v}, t}:
      agg(t, agg.prefixes(String.split(k, '/'), List.length(&2, String, String.split(k, '/')), v, m))

# A direct child path of cur ("" is the root).
def is.child(+cur: String, +e: String) -> Bool:
  Bool.pick(Bool, String.is_empty(cur), Bool.not(String.contains(e, "/")), Bool.and(String.starts_with(e, String.append(cur, "/")), Bool.not(String.contains(String.drop(e, 1n+String.length(cur)), "/"))))

def best.child(+cur: String, +entries: List<&2, Sigma<&2, &2, String, _ => U32>>, +b: Bst) -> Bst:
  match entries:
    case Nil{}:
      b
    case Con{Tuple{+k, +v}, t}:
      Bst{+bk, +bv} = b
      best.child(cur, t, Bool.pick(Bst, Bool.and(is.child(cur, k), U32.is_gt(v, bv)), Bst{k, v}, Bst{bk, bv}))

# Move to the best child only if it holds at least share percent of the current path's score.
def step.next(+cf: String, +cs: U32, ch: Bst, +share: U32) -> Bst:
  Bst{+f2, +s2} = ch
  Bool.pick(Bst, Bool.and(U32.is_gt(s2, 0), U32.is_ge((s2 * 100 : U32), (share * cs : U32))), Bst{f2, s2}, Bst{cf, cs})

def descend(+fuel: Nat, cur: Bst, +entries: List<&2, Sigma<&2, &2, String, _ => U32>>, +share: U32) -> Bst:
  match fuel:
    case 0n:
      cur
    case 1n+p:
      Bst{+cf, +cs} = cur
      descend(p, step.next(cf, cs, best.child(cf, entries, Bst{"", 0}), share), entries, share)

def pick.fin(item: Model.Item, b: Bst) -> Cl:
  Bst{folder, score} = b
  Cl{item, folder, score}

def pick.best(+item: Model.Item, scores: Map<&2, U32>) -> Cl:
  pick.fin(item, descend(12n, Bst{"", 0}, Map.to_list(&2, U32, agg(Map.to_list(&2, U32, scores), Map.new(&2, U32))), 15))

# ---- strict rules: a configured word or host decides the folder outright ----

def has.tok(toks: List<&2, String>, +w: String) -> Bool:
  match toks:
    case Nil{}:
      False{}
    case Con{t, rest}:
      Bool.or(String.eq(t, w), has.tok(rest, w))

def word.hit(+toks: List<&2, String>, words: List<&2, String>) -> Bool:
  match words:
    case Nil{}:
      False{}
    case Con{w, rest}:
      Bool.or(has.tok(toks, String.to_lower(w)), word.hit(toks, rest))

# The host is h or a subdomain of h.
def host.hit(+host: String, hosts: List<&2, String>) -> Bool:
  match hosts:
    case Nil{}:
      False{}
    case Con{+h, rest}:
      Bool.or(Bool.or(String.eq(host, String.to_lower(h)), String.ends_with(host, String.append(".", String.to_lower(h)))), host.hit(host, rest))

def strict.merge(hit: Bool, +path: String, rest: Bst) -> Bst:
  Bool.pick(Bst, hit, Bst{path, 99999}, rest)

# First strict folder (in config order) whose words or hosts match; score 99999, or ("", 0) when none do.
def strict.pick(strict: List<&2, Config.Fh>, +toks: List<&2, String>, +host: String) -> Bst:
  match strict:
    case Nil{}:
      Bst{"", 0}
    case Con{fh, t}:
      Config.Fh{+path, desc, +hosts, +words, flag} = fh
      strict.merge(Bool.or(host.hit(host, hosts), word.hit(toks, words)), path, strict.pick(t, toks, host))

def pick.strict(sb: Bst, cl: Cl) -> Cl:
  Bst{+f, +s} = sb
  Cl{+item, +cf, +cs} = cl
  Bool.pick(Cl, U32.is_gt(s, 0), Cl{item, f, s}, Cl{item, cf, cs})

def classify.one(+ix: Ix, +item: Model.Item) -> Cl:
  Ix{+idx, sz, +strict} = ix
  Model.Item{+folder, +title, +url, +added} = item
  pick.strict(strict.pick(strict, tokens(title, url), String.to_lower(host(url))), pick.best(Model.Item{folder, title, url, added}, score.all(tokens(title, url), idx, Map.new(&2, U32))))

def classify.each(+ix: Ix, items: List<&2, Model.Item>) -> List<&2, Cl>:
  match items:
    case Nil{}:
      []
    case Con{it, t}:
      classify.one(ix, it) <> classify.each(ix, t)

def in.keep(keep: Bool, it: Model.Item, rest: List<&2, Model.Item>) -> List<&2, Model.Item>:
  match keep:
    case True{}:
      it <> rest
    case False{}:
      rest

# Items filed directly in the inbox folder.
def in.inbox(+inbox: String, +items: List<&2, Model.Item>) -> List<&2, Model.Item>:
  match items:
    case Nil{}:
      Nil{}
    case Con{+it, t}:
      Model.Item{+folder, title, url, added} = it
      in.keep(String.eq(folder, inbox), it, in.inbox(inbox, t))

# Suggestions for every inbox item, using the rest of the DB as the training set.
def suggest(+items: List<&2, Model.Item>, +inbox: String, +folders: List<&2, Config.Fh>) -> List<&2, Cl>:
  classify.each(index(items, inbox, folders), in.inbox(inbox, items))

# Apply suggestions scoring at least min; everything else stays as it is. Order is kept.
def apply.one(cl: Cl, +min: U32) -> Model.Item:
  Cl{item, +folder, +score} = cl
  Model.Item{f0, title, url, added} = item
  Model.Item{Bool.pick(String, Bool.and(U32.is_ge(score, min), Bool.not(String.is_empty(folder))), folder, f0), title, url, added}

# The whole DB with inbox items moved to their suggested folder when it scores at least min.
def apply.all(+ix: Ix, +inbox: String, +min: U32, items: List<&2, Model.Item>) -> List<&2, Model.Item>:
  match items:
    case Nil{}:
      []
    case Con{+it, t}:
      Model.Item{+folder, title, url, added} = it
      Bool.pick(Model.Item, String.eq(folder, inbox), apply.one(classify.one(ix, it), min), it) <> apply.all(ix, inbox, min, t)

# Hold out every k-th bookmark and classify it from the rest: how often is the pick right, wrong, or below the threshold?
type Sp is Data:
  Sp{held: List<&2, Model.Item>, rest: List<&2, Model.Item>}

type Ev is Data:
  Ev{ok: U32, bad: U32, none: U32}

def next.i(+i: U32, +k: U32) -> U32:
  Bool.pick(U32, U32.is_ge((i + 1 : U32), k), 0, (i + 1 : U32))

def split(items: List<&2, Model.Item>, +k: U32, +i: U32, +inbox: String, +held: List<&2, Model.Item>, +rest: List<&2, Model.Item>) -> Sp:
  match items:
    case Nil{}:
      Sp{held, rest}
    case Con{+it, t}:
      Model.Item{+folder, title, url, added} = it
      +hit = Bool.and(U32.is_eq(i, 0), Bool.not(String.eq(folder, inbox)))
      split(t, k, next.i(i, k), inbox, Bool.pick(List<&2, Model.Item>, hit, it <> held, held), Bool.pick(List<&2, Model.Item>, hit, rest, it <> rest))

def ev.add(+none: Bool, +right: Bool, ev: Ev) -> Ev:
  Ev{ok, bad, n} = ev
  Ev{(ok + Bool.to_u32(Bool.and(Bool.not(none), right)) : U32), (bad + Bool.to_u32(Bool.and(Bool.not(none), Bool.not(right))) : U32), (n + Bool.to_u32(none) : U32)}

# The first d segments of a path; the whole path when d is 0.
def trim(+path: String, +d: Nat) -> String:
  Bool.pick(String, Nat.is_eq(d, 0n), path, String.join(List.take(&2, String, String.split(path, '/'), d), "/"))

def ev.count(cls: List<&2, Cl>, +min: U32, +depth: Nat, ev: Ev) -> Ev:
  match cls:
    case Nil{}:
      ev
    case Con{cl, t}:
      Cl{item, +folder, +score} = cl
      Model.Item{+truth, title, url, added} = item
      ev.count(t, min, depth, ev.add(U32.is_lt(score, min), String.eq(trim(truth, depth), trim(folder, depth)), ev))

def eval.sp(sp: Sp, +inbox: String, +min: U32, +depth: Nat, +folders: List<&2, Config.Fh>) -> Ev:
  Sp{held, rest} = sp
  ev.count(classify.each(index(rest, inbox, folders), held), min, depth, Ev{0, 0, 0})

def evaluate(items: List<&2, Model.Item>, +k: U32, +inbox: String, +min: U32, +depth: Nat, +folders: List<&2, Config.Fh>) -> Ev:
  eval.sp(split(items, k, 0, inbox, [], []), inbox, min, depth, folders)

