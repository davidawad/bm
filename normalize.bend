# Two spellings of one page compare equal after normalize: host and scheme lowercase, no fragment, no tracking parameters, no trailing slash.
import Base

def head(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{h, t}:
      h

# Query parameters that identify a visit, not a page.
def tracking(+p: String) -> Bool:
  Bool.or(Bool.or(String.starts_with(p, "utm_"), String.starts_with(p, "fbclid=")), Bool.or(String.starts_with(p, "gclid="), String.starts_with(p, "mc_eid=")))

def keep.param(p: String) -> Bool:
  Bool.not(tracking(p))

def clean.query(+q: String) -> String:
  String.join(List.filter(~String, ~keep.param, String.split(q, '&')), "&")

# Lowercase the first n "/"-separated segments: scheme, empty, host.
def lower.n(n: Nat, segs: List<&2, String>) -> List<&2, String>:
  match n:
    case 0n:
      segs
    case 1n+p:
      match segs:
        case Nil{}:
          Nil{}
        case Con{s, t}:
          String.to_lower(s) <> lower.n(p, t)

def drop.slash.if(slash: Bool, +s: String) -> String:
  match slash:
    case True{}:
      String.take(s, Nat.sub(String.length(s), 1n))
    case False{}:
      s

def drop.slash(+s: String) -> String:
  drop.slash.if(String.ends_with(s, "/"), s)

def rejoin(+base: String, +query: String) -> String:
  Bool.pick(String, String.is_empty(query), base, String.concat([base, "?", query]))

def with.query(+base: String, rest: List<&2, String>) -> String:
  rejoin(drop.slash(String.join(lower.n(3n, String.split(base, '/')), "/")), clean.query(String.join(rest, "?")))

def with.parts(parts: List<&2, String>) -> String:
  match parts:
    case Nil{}:
      ""
    case Con{base, rest}:
      with.query(base, rest)

def web.url(+url: String) -> String:
  with.parts(String.split(head(String.split(url, '#')), '?'))

# Only http(s) URLs are rewritten; javascript: bookmarklets and other schemes are compared as written.
def normalize(+url: String) -> String:
  +low = String.to_lower(url)
  Bool.pick(String, Bool.or(String.starts_with(low, "http://"), String.starts_with(low, "https://")), web.url(url), url)
