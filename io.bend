# Whole-file read and write over bend-kit-files, chunked because one read returns at most 1 MiB.
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-kit-files@0.2.0.0/files.bend as Fs

# State of the read loop: keep reading, hit end of file, or failed.
type Step is Type:
  Run{h: File, acc: List<&1, Bytes.Bytes>}
  Eof{h: File, acc: List<&1, Bytes.Bytes>}
  Err{}

def read.more(h: File, acc: List<&1, Bytes.Bytes>, b: Bytes.Bytes, empty: Bool) -> Step:
  match empty:
    case True{}:
      Eof{h, acc}
    case False{}:
      Run{h, b <> acc}

def read.len(h: File, acc: List<&1, Bytes.Bytes>, p: Bytes.Bytes & U32) -> Step:
  match p:
    case (b, n):
      read.more(h, acc, b, U32.is_eq(n, 0))

def read.fold(acc: List<&1, Bytes.Bytes>, pair: File & Result<&1, &1, U32 & String, Bytes.Bytes>) -> Step:
  match pair:
    case (h, r):
      match r:
        case Fail{e}:
          Err{}
        case Done{b}:
          read.len(h, acc, Bytes.length(b))

# Reads the rest of an open file; newest chunk first. Fuel bounds the chunk count (1 MiB each).
def read.loop(fuel: Nat, st: Step) -> IO(List<&1, Bytes.Bytes>):
  match fuel:
    case 0n:
      IO.die(List<&1, Bytes.Bytes>, 1, "file too large")
    case 1n+p:
      match st:
        case Err{}:
          IO.die(List<&1, Bytes.Bytes>, 1, "read failed")
        case Eof{h, acc}:
          do IO<List<&1, Bytes.Bytes>>:
            File.close(h)
            return acc
        case Run{h, acc}:
          do IO<List<&1, Bytes.Bytes>>:
            pair : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(h, 1048576)
            read.loop(p, read.fold(acc, pair))

def read.opened(path: String, r: Result<&1, &1, U32 & String, File>) -> IO(List<&1, Bytes.Bytes>):
  match r:
    case Fail{e}:
      IO.die(List<&1, Bytes.Bytes>, 1, String.concat(["cannot open ", path]))
    case Done{f}:
      read.loop(4096n, Run{f, []})

# The whole file as one Bytes; exits with a message when it cannot be opened.
def read.file(+path: String) -> IO(Bytes.Bytes):
  do IO<Bytes.Bytes>:
    o : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    chunks : List<&1, Bytes.Bytes> <- read.opened(path, o)
    return Bytes.concat(List.reverse(&1, Bytes.Bytes, chunks))

def write.done(pair: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match pair:
    case (h, r):
      match r:
        case Fail{e}:
          IO.die(Unit, 1, "write failed")
        case Done{u}:
          File.close(h)

def write.opened(data: Bytes.Bytes, path: String, r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, String.concat(["cannot open ", path, " for writing"]))
    case Done{f}:
      do IO<Unit>:
        pair : File & Result<&1, &1, U32 & String, Unit> <- Fs.write_bytes(f, data)
        write.done(pair)

# Replaces the file's contents.
def write.file(+path: String, data: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    o : Result<&1, &1, U32 & String, File> <- File.open(path, "w")
    write.opened(data, path, o)

# Raw bytes to stdout. Octet strings must not go through IO.print, which would re-encode each byte above 127 as UTF-8.
def out(+s: String) -> IO(Unit):
  do IO<Unit>:
    o : Result<&1, &1, U32 & String, File> <- File.open("/dev/stdout", "a")
    write.opened(Bytes.from_string(s), "/dev/stdout", o)

def out.line(+s: String) -> IO(Unit):
  out(String.append(s, "\n"))
