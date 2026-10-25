# Full gate: lint, typecheck, then run the behavior checks natively.
set shell := ["sh", "-eu", "-c"]

default: check

lint:
    awk -f lint.awk *.bend

check: lint
    bend main.bend -o "${TMPDIR:-/tmp}/bm-main"
    bend check.bend -o "${TMPDIR:-/tmp}/bm-check"
    "${TMPDIR:-/tmp}/bm-check"

# Build the binary here (bin/bm builds into ~/.cache/bm on its own).
build:
    bend main.bend -o bm
