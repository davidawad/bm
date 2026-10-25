# Bool.pick evaluates both branches. A recursive call in each branch makes the def exponential in its input
# (a tree walk over 3000 bookmarks never finishes). Flags any def line that calls the def twice inside one Bool.pick.
# Run: awk -f lint.awk *.bend
FNR == 1 { name = "" }
/^def / { name = $2; sub(/\(.*/, "", name) }
/Bool\.pick/ && name != "" {
  n = 0; rest = $0
  while ((i = index(rest, name "(")) > 0) { n++; rest = substr(rest, i + length(name) + 1) }
  if (n >= 2) { printf "%s:%d: %s calls itself in more than one Bool.pick branch\n", FILENAME, FNR, name; bad = 1 }
}
END { exit bad }
