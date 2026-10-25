# Chromium timestamps (microseconds since 1601-01-01 UTC, kept as decimal text in the DB) -> ISO 8601, in U32 arithmetic only.
# Seconds since 1601 overflow U32, so the value is split into a 4-digit tail and the rest and divided by 86400 in two steps.
import Base

# Digits of s as a number, 0 for anything else.
def num(s: String) -> U32:
  Maybe.default(&2, U32, U32.read(s), 0)

def pad2(+n: U32) -> String:
  Bool.pick(String, U32.is_lt(n, 10), String.append("0", U32.show(n)), U32.show(n))

# Civil date from days since 1600-03-01 (which starts a 400-year Gregorian cycle of 146097 days), one step per def.
def civil.out(+month: U32, +day: U32, +y0: U32) -> String:
  String.concat([U32.show(Bool.pick(U32, U32.is_le(month, 2), (y0 + 1601 : U32), (y0 + 1600 : U32))), "-", pad2(month), "-", pad2(day)])

def civil.fin(+y0: U32, +mp: U32, +day: U32) -> String:
  civil.out(Bool.pick(U32, U32.is_lt(mp, 10), (mp + 3 : U32), (mp - 9 : U32)), day, y0)

def civil.mp(+era: U32, +yoe: U32, +doy: U32, +mp: U32) -> String:
  civil.fin((yoe + (era * 400 : U32) : U32), mp, ((doy - (((153 * mp : U32) + 2 : U32) / 5 : U32) : U32) + 1 : U32))

def civil.doy(+era: U32, +yoe: U32, +doy: U32) -> String:
  civil.mp(era, yoe, doy, (((5 * doy : U32) + 2 : U32) / 153 : U32))

def civil.yoe(+era: U32, +doe: U32, +yoe: U32) -> String:
  civil.doy(era, yoe, (doe - (((365 * yoe : U32) + (yoe / 4 : U32) : U32) - (yoe / 100 : U32) : U32) : U32))

def civil.doe(+era: U32, +doe: U32) -> String:
  civil.yoe(era, doe, ((((doe - (doe / 1460 : U32) : U32) + (doe / 36524 : U32) : U32) - (doe / 146096 : U32) : U32) / 365 : U32))

def civil(+z: U32) -> String:
  civil.doe((z / 146097 : U32), (z % 146097 : U32))

# (days since 1601-01-01, seconds into the day)
type Dt is Data:
  Dt{days: U32, secs: U32}

def split.fin(+q1: U32, +rest: U32) -> Dt:
  Dt{((q1 * 10000 : U32) + (rest / 86400 : U32) : U32), (rest % 86400 : U32)}

def split.parts(+a: U32, +b: U32) -> Dt:
  split.fin((a / 86400 : U32), (((a % 86400 : U32) * 10000 : U32) + b : U32))

# s = whole seconds since 1601 as text (up to 11 digits): head * 10^4 + tail.
def split.at(+s: String) -> Dt:
  split.parts(num(String.take(s, Nat.sub(String.length(s), 4n))), num(String.drop(s, Nat.sub(String.length(s), 4n))))

def split(+us: String) -> Dt:
  split.at(String.take(us, Nat.sub(String.length(us), 6n)))

def clock(+secs: U32) -> String:
  String.concat([pad2((secs / 3600 : U32)), ":", pad2(((secs % 3600 : U32) / 60 : U32)), ":", pad2((secs % 60 : U32))])

def iso.dt(dt: Dt) -> String:
  Dt{+days, +secs} = dt
  String.concat([civil((days + 306 : U32)), "T", clock(secs), "Z"])

# "" for 0 / missing (Safari bookmarks carry no date).
def iso(+us: String) -> String:
  Bool.pick(String, Nat.is_lt(String.length(us), 8n), "", iso.dt(split(us)))
