# Where each browser keeps its bookmarks, relative to $HOME.
import Base

def rel(+b: String) -> String:
  Bool.pick(String, String.eq(b, "chrome"), "/Library/Application Support/Google/Chrome/Default/Bookmarks",
  Bool.pick(String, String.eq(b, "helium"), "/Library/Application Support/net.imput.helium/Default/Bookmarks",
  Bool.pick(String, String.eq(b, "brave"), "/Library/Application Support/BraveSoftware/Brave-Browser/Default/Bookmarks",
  Bool.pick(String, String.eq(b, "edge"), "/Library/Application Support/Microsoft Edge/Default/Bookmarks",
  Bool.pick(String, String.eq(b, "browseros"), "/Library/Application Support/BrowserOS/Default/Bookmarks",
  Bool.pick(String, String.eq(b, "safari"), "/Library/Safari/Bookmarks.plist", ""))))))

def known(+b: String) -> Bool:
  Bool.or(Bool.or(Bool.or(String.eq(b, "chrome"), String.eq(b, "helium")), Bool.or(String.eq(b, "brave"), String.eq(b, "edge"))), Bool.or(String.eq(b, "browseros"), Bool.or(String.eq(b, "safari"), String.eq(b, "file"))))

def safari(+b: String) -> Bool:
  String.eq(b, "safari")

def resolve(+home: String, +b: String, over: Maybe<&2, String>) -> String:
  match over:
    case Some{p}:
      p
    case None{}:
      String.append(home, rel(b))
