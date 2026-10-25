# Output formats for tables of text cells: tsv, csv, json, jsonl, toon (v3, tabular arrays), md and an aligned table.
# A column named count, depth or id holds a number; every other cell is text. Text is octets (UTF-8 bytes), passed through as is.
import Base
import bend-kit-json@0.6.1.1/json.bend as Json
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes

type Row is Data:
  Row{cells: List<&2, String>}

def numeric(+f: String) -> Bool:
  Bool.or(Bool.or(String.eq(f, "count"), String.eq(f, "depth")), String.eq(f, "id"))

def quote(+s: String) -> String:
  String.concat(["\"", s, "\""])

# ---- escaping, one char at a time ----

def hex1(+n: U32) -> String:
  String.from_list([Chr{Bool.pick(U32, U32.is_lt(n, 10), (n + 48 : U32), (n + 87 : U32))}])

def ctl(+code: U32) -> String:
  String.concat(["\\u00", hex1((code / 16 : U32)), hex1((code % 16 : U32))])

# JSON and TOON string escapes.
def esc.code(+code: U32) -> String:
  Bool.pick(String, U32.is_eq(code, 92), "\\\\",
  Bool.pick(String, U32.is_eq(code, 34), "\\\"",
  Bool.pick(String, U32.is_eq(code, 10), "\\n",
  Bool.pick(String, U32.is_eq(code, 13), "\\r",
  Bool.pick(String, U32.is_eq(code, 9), "\\t",
  Bool.pick(String, U32.is_lt(code, 32), ctl(code), String.from_list([Chr{code}])))))))

def esc.char(c: Char) -> String:
  match c:
    case Chr{code}:
      esc.code(code)

def esc(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{c, t}:
      String.append(esc.char(c), esc(t))

# ---- JSON ----

def jstr(+s: String) -> String:
  Bytes.to_string(Json.encode.bytes(Json.Str{Bytes.from_string(s)}))

def jval(+f: String, +v: String) -> String:
  Bool.pick(String, Bool.and(numeric(f), Bool.not(String.is_empty(v))), v, jstr(v))

def jfields(fields: List<&2, String>, cells: List<&2, String>) -> List<&2, String>:
  match fields:
    case Nil{}:
      []
    case Con{+f, ft}:
      match cells:
        case Nil{}:
          []
        case Con{c, ct}:
          String.concat([jstr(f), ":", jval(f, c)]) <> jfields(ft, ct)

def jobj(+fields: List<&2, String>, +cells: List<&2, String>) -> String:
  String.concat(["{", String.join(jfields(fields, cells), ","), "}"])

def jlines(+fields: List<&2, String>, rows: List<&2, Row>) -> List<&2, String>:
  match rows:
    case Nil{}:
      []
    case Con{r, t}:
      Row{cells} = r
      jobj(fields, cells) <> jlines(fields, t)

def nl(ls: List<&2, String>) -> String:
  match ls:
    case Nil{}:
      ""
    case Con{l, t}:
      String.concat([l, "\n", nl(t)])

def jsonl(fields: List<&2, String>, rows: List<&2, Row>) -> String:
  nl(jlines(fields, rows))

def json(fields: List<&2, String>, rows: List<&2, Row>) -> String:
  String.concat(["[\n", String.join(jlines(fields, rows), ",\n"), "\n]\n"])

# ---- CSV / TSV / Markdown ----

def csv.need(+s: String) -> Bool:
  Bool.or(Bool.or(Bool.or(String.contains(s, ","), String.contains(s, "\"")), Bool.or(String.contains(s, "\n"), String.contains(s, "\r"))), Bool.or(String.starts_with(s, " "), String.ends_with(s, " ")))

# Double the quotes inside.
def dq(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, t}:
      String.append(Bool.pick(String, U32.is_eq(c, 34), "\"\"", String.from_list([Chr{c}])), dq(t))

def csv.cell(+s: String) -> String:
  Bool.pick(String, csv.need(s), String.concat(["\"", dq(s), "\""]), s)

def csv.row(+cells: List<&2, String>) -> String:
  match cells:
    case Nil{}:
      ""
    case Con{c, t}:
      String.append(csv.cell(c), Bool.pick(String, List.is_empty(&2, String, t), "", String.append(",", csv.row(t))))

def csv.rows(rows: List<&2, Row>) -> String:
  match rows:
    case Nil{}:
      ""
    case Con{r, t}:
      Row{cells} = r
      String.concat([csv.row(cells), "\r\n", csv.rows(t)])

def csv(+fields: List<&2, String>, rows: List<&2, Row>) -> String:
  String.append(String.append(csv.row(fields), "\r\n"), csv.rows(rows))

# Tabs and newlines would break the layout.
def flat.code(+code: U32) -> String:
  Bool.pick(String, Bool.or(Bool.or(U32.is_eq(code, 9), U32.is_eq(code, 10)), U32.is_eq(code, 13)), " ", String.from_list([Chr{code}]))

def flat.char(c: Char) -> String:
  match c:
    case Chr{code}:
      flat.code(code)

def flat(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{c, t}:
      String.append(flat.char(c), flat(t))

def flat.all(cells: List<&2, String>) -> List<&2, String>:
  match cells:
    case Nil{}:
      []
    case Con{c, t}:
      flat(c) <> flat.all(t)

def tsv.rows(rows: List<&2, Row>) -> String:
  match rows:
    case Nil{}:
      ""
    case Con{r, t}:
      Row{cells} = r
      String.concat([String.join(flat.all(cells), "\t"), "\n", tsv.rows(t)])

def tsv(+fields: List<&2, String>, rows: List<&2, Row>) -> String:
  String.append(String.append(String.join(fields, "\t"), "\n"), tsv.rows(rows))

def md.cell(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, t}:
      String.append(Bool.pick(String, U32.is_eq(c, 124), "\\|", flat.code(c)), md.cell(t))

def md.cells(cells: List<&2, String>) -> List<&2, String>:
  match cells:
    case Nil{}:
      []
    case Con{c, t}:
      md.cell(c) <> md.cells(t)

def md.line(cells: List<&2, String>) -> String:
  String.concat(["| ", String.join(md.cells(cells), " | "), " |\n"])

def md.rows(rows: List<&2, Row>) -> String:
  match rows:
    case Nil{}:
      ""
    case Con{r, t}:
      Row{cells} = r
      String.append(md.line(cells), md.rows(t))

def rule.cells(fields: List<&2, String>) -> List<&2, String>:
  match fields:
    case Nil{}:
      []
    case Con{f, t}:
      "---" <> rule.cells(t)

def md.rule(fields: List<&2, String>) -> String:
  md.line(rule.cells(fields))

def md(+fields: List<&2, String>, rows: List<&2, Row>) -> String:
  String.concat([md.line(fields), md.rule(fields), md.rows(rows)])

# ---- TOON ----

# A string that reads like a number: -?digits[.digits][e[+-]digits]. State machine over the chars; 1, 3, 6 accept.
def num.step(+st: U32, +c: U32) -> U32:
  +digit = Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57))
  Bool.pick(U32, U32.is_eq(st, 0), Bool.pick(U32, digit, 1, Bool.pick(U32, U32.is_eq(c, 45), 7, 9)),
  Bool.pick(U32, U32.is_eq(st, 7), Bool.pick(U32, digit, 1, 9),
  Bool.pick(U32, U32.is_eq(st, 1), Bool.pick(U32, digit, 1, Bool.pick(U32, U32.is_eq(c, 46), 2, Bool.pick(U32, Bool.or(U32.is_eq(c, 101), U32.is_eq(c, 69)), 4, 9))),
  Bool.pick(U32, U32.is_eq(st, 2), Bool.pick(U32, digit, 3, 9),
  Bool.pick(U32, U32.is_eq(st, 3), Bool.pick(U32, digit, 3, Bool.pick(U32, Bool.or(U32.is_eq(c, 101), U32.is_eq(c, 69)), 4, 9)),
  Bool.pick(U32, U32.is_eq(st, 4), Bool.pick(U32, digit, 6, Bool.pick(U32, Bool.or(U32.is_eq(c, 43), U32.is_eq(c, 45)), 5, 9)),
  Bool.pick(U32, U32.is_eq(st, 5), Bool.pick(U32, digit, 6, 9),
  Bool.pick(U32, U32.is_eq(st, 6), Bool.pick(U32, digit, 6, 9), 9))))))))

def num.go(s: String, +st: U32) -> U32:
  match s:
    case SNil{}:
      st
    case SCon{Chr{c}, t}:
      num.go(t, num.step(st, c))

def numeric.like(+s: String) -> Bool:
  +st = num.go(s, 0)
  Bool.or(Bool.or(U32.is_eq(st, 1), U32.is_eq(st, 3)), U32.is_eq(st, 6))

# Control characters (U+0000..U+001F) anywhere in the string.
def ctl.in(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{c}, t}:
      Bool.or(U32.is_lt(c, 32), ctl.in(t))

def ws.edge(+s: String) -> Bool:
  Bool.or(String.starts_with(s, " "), String.ends_with(s, " "))

# Quote when empty, padded, true/false/null, number-like, containing : " \ [ ] { } , or a control character, or starting with "-".
def toon.need(+s: String) -> Bool:
  Bool.or(Bool.or(Bool.or(String.is_empty(s), ws.edge(s)), Bool.or(Bool.or(String.eq(s, "true"), String.eq(s, "false")), Bool.or(String.eq(s, "null"), numeric.like(s)))),
  Bool.or(Bool.or(Bool.or(Bool.or(String.contains(s, ":"), String.contains(s, "\"")), Bool.or(String.contains(s, "\\"), String.contains(s, "["))), Bool.or(Bool.or(String.contains(s, "]"), String.contains(s, "{")), Bool.or(String.contains(s, "}"), String.contains(s, ",")))),
  Bool.or(ctl.in(s), String.starts_with(s, "-"))))

def toon.str(+s: String) -> String:
  Bool.pick(String, toon.need(s), String.concat(["\"", esc(s), "\""]), s)

def toon.cell(+f: String, +v: String) -> String:
  Bool.pick(String, Bool.and(numeric(f), Bool.not(String.is_empty(v))), v, toon.str(v))

def toon.cells(fields: List<&2, String>, cells: List<&2, String>) -> List<&2, String>:
  match fields:
    case Nil{}:
      []
    case Con{f, ft}:
      match cells:
        case Nil{}:
          []
        case Con{c, ct}:
          toon.cell(f, c) <> toon.cells(ft, ct)

def toon.rows(+fields: List<&2, String>, rows: List<&2, Row>) -> String:
  match rows:
    case Nil{}:
      ""
    case Con{r, t}:
      Row{cells} = r
      String.concat(["  ", String.join(toon.cells(fields, cells), ","), "\n", toon.rows(fields, t)])

# name[N]{f1,f2}: then one comma-separated row per line, indented two spaces.
def toon(+name: String, +fields: List<&2, String>, +rows: List<&2, Row>) -> String:
  Bool.pick(String, List.is_empty(&2, Row, rows), String.concat([name, ": []\n"]), String.concat([name, "[", Nat.show(List.length(&2, Row, rows)), "]{", String.join(fields, ","), "}:\n", toon.rows(fields, rows)]))

# ---- aligned table ----

def width.of(+cells: List<&2, String>) -> List<&2, Nat>:
  match cells:
    case Nil{}:
      []
    case Con{c, t}:
      Nat.min(String.length(c), 48n) <> width.of(t)

def widen(ws: List<&2, Nat>, vs: List<&2, Nat>) -> List<&2, Nat>:
  match ws:
    case Nil{}:
      vs
    case Con{w, wt}:
      match vs:
        case Nil{}:
          ws
        case Con{v, vt}:
          Nat.max(w, v) <> widen(wt, vt)

def widths(rows: List<&2, Row>, ws: List<&2, Nat>) -> List<&2, Nat>:
  match rows:
    case Nil{}:
      ws
    case Con{r, t}:
      Row{cells} = r
      widths(t, widen(ws, width.of(cells)))

def cut(+c: String, +w: Nat) -> String:
  Bool.pick(String, Nat.is_gt(String.length(c), w), String.append(String.take(c, Nat.sub(w, 1n)), "~"), c)

def pad(+c: String, +w: Nat) -> String:
  String.append(cut(flat(c), w), String.repeat(" ", Nat.sub(w, Nat.min(String.length(cut(flat(c), w)), w))))

def line(+cells: List<&2, String>, ws: List<&2, Nat>) -> String:
  match cells:
    case Nil{}:
      ""
    case Con{c, ct}:
      match ws:
        case Nil{}:
          ""
        case Con{+w, wt}:
          String.append(String.append(Bool.pick(String, List.is_empty(&2, String, ct), cut(flat(c), w), pad(c, w)), Bool.pick(String, List.is_empty(&2, String, ct), "", "  ")), line(ct, wt))

def lines(rows: List<&2, Row>, +ws: List<&2, Nat>) -> String:
  match rows:
    case Nil{}:
      ""
    case Con{r, t}:
      Row{cells} = r
      String.concat([line(cells, ws), "\n", lines(t, ws)])

def table.ws(+fields: List<&2, String>, rows: List<&2, Row>, +ws: List<&2, Nat>) -> String:
  String.append(String.append(line(fields, ws), "\n"), lines(rows, ws))

def table(+fields: List<&2, String>, +rows: List<&2, Row>) -> String:
  table.ws(fields, rows, widths(rows, width.of(fields)))
