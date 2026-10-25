# Folder paths as segment lists ("a/b/c" <-> ["a", "b", "c"]) and the diff between two of them.
import Base

def split(+path: String) -> List<&2, String>:
  String.split(path, '/')

# Segments after the first; the browser root is the first segment.
def tail(xs: List<&2, String>) -> List<&2, String>:
  List.tail(&2, String, xs)

# (how many folders must close, folders that must open) to move from cur to tgt.
def diff.pick(same: Bool, deeper: Nat & List<&2, String>, fallback: Nat & List<&2, String>) -> Nat & List<&2, String>:
  Bool.pick(Nat & List<&2, String>, same, deeper, fallback)

def diff(+cur: List<&2, String>, +tgt: List<&2, String>) -> Nat & List<&2, String>:
  match cur:
    case Nil{}:
      (0n, tgt)
    case Con{c, ct}:
      match tgt:
        case Nil{}:
          (List.length(&2, String, cur), Nil{})
        case Con{t, tt}:
          diff.pick(String.eq(c, t), diff(ct, tt), (List.length(&2, String, cur), tgt))
