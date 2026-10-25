# Merge browser items into the DB. The DB wins: a URL it already has (by normalized form) is skipped, never moved, retitled or deleted.
import Base
import ./model.bend as Model
import ./normalize.bend as Norm

type Mg is Type:
  Mg{known: Set(), fresh: List<&2, Model.Item>, added: Nat, skipped: Nat, seed: Bool, inbox: String}

def index.known(items: List<&2, Model.Item>, set: Set()) -> Set():
  match items:
    case Nil{}:
      set
    case Con{it, t}:
      Model.Item{folder, title, +url, added} = it
      index.known(t, Set.add(set, Norm.normalize(url)))

# Everything with a URL is kept, bookmarklets and browser-internal pages included.
def web(+url: String) -> Bool:
  Bool.not(String.is_empty(url))

# New items sitting directly in a browser root (uncategorized) go to the Inbox.
def fix.folder(+folder: String, +inbox: String) -> String:
  Bool.pick(String, String.contains(folder, "/"), folder, inbox)

def merge.skip(mg: Mg) -> Mg:
  Mg{known, fresh, added, skipped, seed, inbox} = mg
  Mg{known, fresh, added, 1n+skipped, seed, inbox}

def merge.add(+key: String, it: Model.Item, mg: Mg) -> Mg:
  Model.Item{+folder0, title, url, added0} = it
  Mg{known, fresh, added, skipped, +seed, +inbox} = mg
  +folder = Bool.pick(String, String.is_empty(folder0), "other", folder0)
  Mg{Set.add(known, key), Model.Item{Bool.pick(String, seed, folder, fix.folder(folder, inbox)), title, url, added0} <> fresh, 1n+added, skipped, seed, inbox}

def merge.decide(skip: Bool, key: String, it: Model.Item, mg: Mg) -> Mg:
  match skip:
    case True{}:
      merge.skip(mg)
    case False{}:
      merge.add(key, it, mg)

def merge.one(+key: String, +ok: Bool, it: Model.Item, hp: Set() & Bool, mg: Mg) -> Mg:
  (known2, has) = hp
  Mg{known, fresh, added, skipped, seed, inbox} = mg
  merge.decide(Bool.or(has, Bool.not(ok)), key, it, Mg{known2, fresh, added, skipped, seed, inbox})

def merge.items(items: List<&2, Model.Item>, mg: Mg) -> Mg:
  match items:
    case Nil{}:
      mg
    case Con{+it, t}:
      Model.Item{+folder, title, +url, added} = it
      Mg{known, fresh, added2, skipped, +seed, +inbox} = mg
      +key = Bool.pick(String, seed, String.concat([Norm.normalize(url), "\t", folder]), Norm.normalize(url))
      merge.items(t, merge.one(key, web(url), it, Set.has(known, key), Mg{Set.new(), fresh, added2, skipped, seed, inbox}))

def merge.fin(db: List<&2, Model.Item>, mg: Mg) -> List<&2, Model.Item> & Nat & Nat:
  Mg{known, fresh, added, skipped, seed, inbox} = mg
  (List.append(&2, Model.Item, db, List.reverse(&2, Model.Item, fresh)), added, skipped)

# (merged DB, new count, already-known count). Into an empty DB everything keeps its folder; later, uncategorized items go to the Inbox.
def merge(+db: List<&2, Model.Item>, news: List<&2, Model.Item>, inbox: String) -> List<&2, Model.Item> & Nat & Nat:
  merge.fin(db, merge.items(news, Mg{index.known(db, Set.new()), [], 0n, 0n, List.is_empty(&2, Model.Item, db), inbox}))
