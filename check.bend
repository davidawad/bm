# Behavior checks. Build and run: bend check.bend -o c && ./c   (prints "ALL CHECKS PASS" or exits 1 at the first failure)
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import ./model.bend as Model
import ./normalize.bend as Norm
import ./merge.bend as Merge
import ./chromium.bend as Chromium
import ./chromium_out.bend as Out
import ./html_out.bend as Html
import ./store.bend as Store
import ./classify.bend as Classify
import ./plist.bend as Plist
import ./config.bend as Config
import ./date.bend as Date
import ./format.bend as Format
import ./query.bend as Query
import bend-kit-json@0.6.1.1/json.bend as Json

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, String.append("FAIL: ", message))

def item(+folder: String, +title: String, +url: String) -> Model.Item:
  Model.Item{folder, title, url, "0"}

def same.item(a: Model.Item, b: Model.Item) -> Bool:
  Model.Item{fa, ta, ua, aa} = a
  Model.Item{fb, tb, ub, ab} = b
  Bool.and(Bool.and(String.eq(fa, fb), String.eq(ta, tb)), Bool.and(String.eq(ua, ub), String.eq(aa, ab)))

def same.items(a: List<&2, Model.Item>, b: List<&2, Model.Item>) -> Bool:
  match a:
    case Nil{}:
      List.is_empty(&2, Model.Item, b)
    case Con{x, xs}:
      match b:
        case Nil{}:
          False{}
        case Con{y, ys}:
          Bool.and(same.item(x, y), same.items(xs, ys))

def seed() -> List<&2, Model.Item>:
  [item("bookmark_bar/Eng/Tools", "GitHub", "https://github.com/"), item("bookmark_bar/Law", "Court \"Rules\" & <more>", "https://courts.gov/a?x=1"), item("other", "Loose", "http://loose.example/")]

def fixture() -> Bytes.Bytes:
  Bytes.from_string("{\"roots\":{\"bookmark_bar\":{\"children\":[{\"type\":\"folder\",\"name\":\"Eng\",\"children\":[{\"type\":\"url\",\"name\":\"GitHub\",\"url\":\"https://github.com/\",\"date_added\":\"5\"}]},{\"type\":\"url\",\"name\":\"Top\",\"url\":\"https://top.example/\"}]},\"other\":{\"children\":[]},\"synced\":{\"children\":[]}},\"version\":1}")

def count.of(m: Maybe<&1, List<&2, Model.Item>>) -> Nat:
  match m:
    case None{}:
      999n
    case Some{xs}:
      List.length(&2, Model.Item, xs)

def first.folder(m: Maybe<&1, List<&2, Model.Item>>) -> String:
  match m:
    case None{}:
      "?"
    case Some{xs}:
      match xs:
        case Nil{}:
          "?"
        case Con{x, t}:
          Model.Item{f, ti, u, a} = x
          f

def or.empty(m: Maybe<&1, List<&2, Model.Item>>) -> List<&2, Model.Item>:
  match m:
    case Some{xs}:
      xs
    case None{}:
      []

def roundtrip(m: Maybe<&1, List<&2, Model.Item>>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{+xs}:
      same.items(xs, or.empty(Store.decode(Store.encode(xs))))

def chromium.rt.go(+xs: List<&2, Model.Item>, back: Maybe<&1, List<&2, Model.Item>>) -> Bool:
  match back:
    case None{}:
      False{}
    case Some{ys}:
      same.items(List.sort(~Model.Item, ~Out.le.folder, xs), ys)

def chromium.rt(m: Maybe<&1, List<&2, Model.Item>>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{+xs}:
      chromium.rt.go(xs, Chromium.read(Out.render(xs)))

def merge.fin(r: List<&2, Model.Item> & Nat & Nat) -> Nat & Nat & Nat:
  match r:
    case (items, added, skipped):
      (List.length(&2, Model.Item, items), added, skipped)

def merge.counts(r: Nat & Nat & Nat, a: Nat, b: Nat, c: Nat) -> Bool:
  match r:
    case (x, y, z):
      Bool.and(Nat.is_eq(x, a), Bool.and(Nat.is_eq(y, b), Nat.is_eq(z, c)))

def inbox.has(r: List<&2, Model.Item> & Nat & Nat) -> Bool:
  match r:
    case (items, added, skipped):
      Bool.not(List.is_empty(&2, Model.Item, Classify.in.inbox("bookmark_bar/Inbox", items)))

def inbox.in(r: List<&2, Model.Item> & Nat & Nat, +name: String) -> Bool:
  match r:
    case (items, added, skipped):
      Bool.not(List.is_empty(&2, Model.Item, Classify.in.inbox(name, items)))

def suggest.folder(cls: List<&2, Classify.Cl>) -> String:
  match cls:
    case Nil{}:
      "none"
    case Con{cl, t}:
      Classify.Cl{it, f, s} = cl
      f

def classify.db() -> List<&2, Model.Item>:
  [item("bookmark_bar/Dev", "Rust docs", "https://docs.rs/serde/"), item("bookmark_bar/Dev", "tokio rust async", "https://docs.rs/tokio/"), item("bookmark_bar/Cooking", "Pasta recipe", "https://food.example/pasta"), item("bookmark_bar/Inbox", "serde derive macros", "https://docs.rs/serde_derive/")]

def plist.xml() -> String:
  "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>Title</key><string>A &amp; B</string><key>n</key><integer>3</integer><key>d</key><data>AAAA</data><key>xs</key><array><string>x</string><true/></array></dict></plist>"

def plist.ok(m: Maybe<&1, Json.Val>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{v}:
      String.eq(Chromium.val.str(Maybe.default(&1, Json.Val, Json.get(v, "Title"), Json.Null{})), "A & B")

def config.json() -> Bytes.Bytes:
  Bytes.from_string("{\"inbox\":\"Unsorted\",\"min_score\":123,\"llm\":\"echo hi\",\"folders\":[{\"path\":\"Dev/AI\",\"description\":\"models\",\"words\":[\"LLM\"],\"hosts\":[\"huggingface.co\"]},{\"path\":\"Code\",\"hosts\":[\"github.com\"],\"strict\":true}]}")

def config.ok(c: Config.Cfg) -> Bool:
  Config.Cfg{inbox, min, llm, folders} = c
  Bool.and(Bool.and(String.eq(inbox, "Unsorted"), U32.is_eq(min, 123)), Bool.and(String.eq(llm, "echo hi"), Nat.is_eq(List.length(&2, Config.Fh, folders), 2n)))

def config.folders() -> List<&2, Config.Fh>:
  Config.folders.of(Config.parse(config.json()))

# A DB with nothing filed yet: only the configured hints and strict rules can place a bookmark.
def hinted.db() -> List<&2, Model.Item>:
  [item("Unsorted", "LLM prompting tricks", "https://blog.example/post"), item("Unsorted", "some repo", "https://www.github.com/a/b"), item("Unsorted", "weights", "https://huggingface.co/x"), item("Unsorted", "Cat photos", "https://cats.example/")]

def suggest.all(cls: List<&2, Classify.Cl>) -> String:
  match cls:
    case Nil{}:
      ""
    case Con{cl, t}:
      Classify.Cl{it, f, s} = cl
      String.concat([f, ";", suggest.all(t)])

def hosts.db() -> List<&2, Model.Item>:
  [item("bookmark_bar/Dev", "A", "https://github.com/a"), item("bookmark_bar/Dev/Sub", "B", "https://gist.github.com/b"), item("bookmark_bar/Fun", "C", "https://example.com/c"), item("other", "Tokio guide", "https://tokio.rs/")]

def q.host(+h: String, +f: String, +t: String) -> Query.Q:
  Query.Q{f, h, t, "", "", Set.new(), False{}}

def n.sel(+q: Query.Q) -> Nat:
  List.length(&2, Model.Item, Query.select(q, hosts.db()))

def main() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(Norm.normalize("HTTPS://Example.COM/a/?utm_source=x&b=1#frag"), "https://example.com/a?b=1"), "normalize lowercases host, drops utm_*, fragment and trailing slash")
    require(String.eq(Norm.normalize("javascript:(function(){a?b#c})()"), "javascript:(function(){a?b#c})()"), "normalize leaves bookmarklets alone")
    require(Nat.is_eq(count.of(Chromium.read(fixture())), 2n), "chromium reader finds both bookmarks")
    require(String.eq(first.folder(Chromium.read(fixture())), "bookmark_bar/Eng"), "chromium reader nests folder paths")
    require(chromium.rt(Chromium.read(fixture())), "chromium writer output reads back to the same bookmarks")
    require(roundtrip(Chromium.read(fixture())), "store encode/decode round trip")
    require(merge.counts(merge.fin(Merge.merge([], seed(), "bookmark_bar/Inbox")), 3n, 3n, 0n), "seed pull keeps all three, no inbox rewrite")
    require(merge.counts(merge.fin(Merge.merge(seed(), seed(), "bookmark_bar/Inbox")), 3n, 0n, 3n), "second pull of the same items adds nothing")
    require(inbox.has(Merge.merge(seed(), [item("other", "New", "https://new.example/")], "bookmark_bar/Inbox")) , "uncategorized new bookmark goes to the Inbox")
    require(String.contains(Html.render(seed()), "<A HREF=\"https://courts.gov/a?x=1\">Court &quot;Rules&quot; &amp; &lt;more&gt;</A>"), "html export escapes titles")
    require(String.eq(suggest.folder(Classify.suggest(classify.db(), "bookmark_bar/Inbox", [])), "bookmark_bar/Dev"), "classifier files a docs.rs bookmark with the other docs.rs bookmarks")
    require(plist.ok(Plist.parse(plist.xml())), "plist parser decodes entities and skips data")
    require(config.ok(Config.parse(config.json())), "config file parses inbox, min_score, llm and folders")
    require(inbox.in(Merge.merge(seed(), [item("other", "New", "https://new.example/")], "Unsorted"), "Unsorted"), "configured inbox name is used")
    require(String.eq(suggest.all(Classify.suggest(hinted.db(), "Unsorted", config.folders())), "Dev/AI;Code;Dev/AI;;"), "config hints and strict rules file bookmarks with no filed examples")
    require(String.eq(Date.iso("13380436646335475"), "2025-01-04T03:57:26Z"), "chromium timestamp -> ISO (2025-01-04)")
    require(String.eq(Date.iso("13402293381738149"), "2025-09-14T03:16:21Z"), "chromium timestamp -> ISO (2025-09-14)")
    require(String.eq(Date.iso("13345527794039339"), "2023-11-27T03:03:14Z"), "chromium timestamp -> ISO (2023-11-27)")
    require(String.eq(Date.iso("0"), ""), "a missing timestamp has no date")
    require(String.eq(Format.csv(["a", "b"], [Format.Row{["x,y", "q\"r"]}]), "a,b\r\n\"x,y\",\"q\"\"r\"\r\n"), "csv quotes commas and doubles quotes")
    require(String.eq(Format.toon("t", ["a", "b"], [Format.Row{["plain", "has:colon"]}, Format.Row{["", "true"]}, Format.Row{["42", "-x"]}]), "t[3]{a,b}:\n  plain,\"has:colon\"\n  \"\",\"true\"\n  \"42\",\"-x\"\n"), "toon quotes empty, boolean, numeric, colon and leading-hyphen strings")
    require(String.eq(Format.toon("t", ["a"], []), "t: []\n"), "toon empty array")
    require(String.eq(Format.json(["title", "count"], [Format.Row{["a\"b", "3"]}]), "[\n{\"title\":\"a\\\"b\",\"count\":3}\n]\n"), "json escapes strings and leaves counts bare")
    require(String.eq(Format.md(["a"], [Format.Row{["x|y"]}]), "| a |\n| --- |\n| x\\|y |\n"), "markdown escapes pipes")
    require(Nat.is_eq(n.sel(q.host("github.com", "", "")), 2n), "host filter matches subdomains")
    require(Nat.is_eq(n.sel(q.host("", "bookmark_bar/Dev", "")), 2n), "folder filter matches the folder and its subfolders")
    require(Nat.is_eq(n.sel(q.host("", "bookmark_bar/De", "")), 0n), "folder filter matches whole path segments only")
    require(Nat.is_eq(n.sel(q.host("", "", "tokio")), 1n), "text filter searches title and URL, case-insensitively")
    IO.print("ALL CHECKS PASS")
