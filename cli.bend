# Command-line argument helpers: `--name value` options, `--name` flags, and positionals.
import Base

def member(+x: String, xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      Bool.or(String.eq(x, h), member(x, t))

# Options that take a value, so their value is not a positional.
def takes.value(+a: String) -> Bool:
  member(a, ["--db", "--path", "--title", "--folder", "--min", "--every", "--depth", "--out", "--llm", "--config", "--host", "--text", "--since", "--until", "--sort", "--limit", "--fields", "--format", "--by"])

def copy(xs: List<&1, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      []
    case Con{h, t}:
      h <> copy(t)

def opt(+args: List<&2, String>, +name: String) -> Maybe<&2, String>:
  match args:
    case Nil{}:
      None{}
    case Con{a, t}:
      match t:
        case Nil{}:
          None{}
        case Con{v, rest}:
          Bool.pick(Maybe<&2, String>, String.eq(a, name), Some{v}, opt(t, name))

def flag(+args: List<&2, String>, +name: String) -> Bool:
  match args:
    case Nil{}:
      False{}
    case Con{a, t}:
      Bool.or(String.eq(a, name), flag(t, name))

def drop.value(takes: Bool, +rest: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, takes, List.tail(&2, String, rest), rest)

def keep.pos(is_opt: Bool, a: String, rest: List<&2, String>) -> List<&2, String>:
  match is_opt:
    case True{}:
      rest
    case False{}:
      a <> rest

# Arguments that are neither options nor option values. Fuel is the argument count.
def positionals(+fuel: Nat, +args: List<&2, String>) -> List<&2, String>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+p:
      match args:
        case Nil{}:
          Nil{}
        case Con{a, t}:
          keep.pos(String.starts_with(a, "--"), a, positionals(p, Bool.pick(List<&2, String>, String.starts_with(a, "--"), drop.value(takes.value(a), t), t)))

def pos(+args: List<&2, String>) -> List<&2, String>:
  positionals(List.length(&2, String, args), args)

def nth(+xs: List<&2, String>, n: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, xs, n), "")

def nat.or(m: Maybe<&2, Nat>, d: Nat) -> Nat:
  Maybe.default(&2, Nat, m, d)

def u32.or(m: Maybe<&2, U32>, d: U32) -> U32:
  Maybe.default(&2, U32, m, d)
