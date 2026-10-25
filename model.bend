# Bookmark model shared by every bm module. Text is held as octet strings (one Char per UTF-8 byte), the form bend-kit-bytes uses.
import Base

# folder is a "/"-joined path whose first segment is a browser root (bookmark_bar, other, synced).
type Item is Data:
  Item{folder: String, title: String, url: String, added: String}

# Where bookmarks go when nothing says otherwise.
def inbox() -> String:
  "bookmark_bar/Inbox"
