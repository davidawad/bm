# Loading and saving the bookmark DB file.
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-kit-files@0.2.0.0/files.bend as Fs
import ./model.bend as Model
import ./io.bend as Io
import ./store.bend as Store

def decoded(m: Maybe<&1, List<&2, Model.Item>>) -> IO(List<&2, Model.Item>):
  match m:
    case Some{xs}:
      IO.pure(List<&2, Model.Item>, xs)
    case None{}:
      IO.die(List<&2, Model.Item>, 1, "the DB file is not valid bm JSON")

def loaded(path: String, there: Bool) -> IO(List<&2, Model.Item>):
  match there:
    case False{}:
      IO.pure(List<&2, Model.Item>, [])
    case True{}:
      do IO<List<&2, Model.Item>>:
        b : Bytes.Bytes <- Io.read.file(path)
        decoded(Store.decode(b))

# A missing DB file is an empty DB.
def load(+path: String) -> IO(List<&2, Model.Item>):
  do IO<List<&2, Model.Item>>:
    there : Bool <- Fs.exists(path)
    loaded(path, there)

def save(+path: String, items: List<&2, Model.Item>) -> IO(Unit):
  Io.write.file(path, Store.encode(items))
