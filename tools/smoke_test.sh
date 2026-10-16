#!/usr/bin/env bash
# ================================================================
# tools/smoke_test.sh — run tools/smoke_test.wl so that the report says
# how the run ended, even when the Wolfram kernel dies.
#
# Usage (macOS, Linux; any smoke_test.wl option is passed through):
#   tools/smoke_test.sh                     all apps + demo.wl
#   tools/smoke_test.sh --quick             6 apps + demo.wl --quick
#   tools/smoke_test.sh --resume            continue an interrupted run
#
# What it adds to a plain `wolframscript -file tools/smoke_test.wl`:
# - The console goes to the terminal and to smoke_console_<...>.txt next
#   to the report.
# - Every 10 s while the kernel runs it rewrites smoke_heartbeat_<...>.txt
#   next to the report: the local time, the seconds since the start and
#   the app being run (the console's last "running <app> ..." line; the
#   report itself holds only finished apps). After a crash or a power
#   loss it shows when the run was last alive and where.
# - When wolframscript ends it appends one line to the report, e.g.
#     The smoke test process ended at 01:52 with exit code 139 (SIGSEGV,
#     segmentation fault) after 2103 s.
#   A kernel killed by a signal makes wolframscript exit with 128 + the
#   signal number, which is how the signal is named. If the report already
#   ends with its Summary line, only the end time is appended.
# The wrapper exits with wolframscript's exit code.
# This is the way to run the smoke test on a machine nobody is watching
# (see the README, Supported platforms, Linux).
# ================================================================

set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
start=$(date +%s)

# the report this run writes: --out=<path> if given, otherwise the newest
# smoke_test_*.txt in the repository root written since the start
out=""
for a in "$@"; do case "$a" in --out=*) out="${a#--out=}";; esac; done

report_path() {
  if [ -n "$out" ]; then [ -f "$out" ] && echo "$out"; return; fi
  local f newest="" newest_t=0 t
  for f in "$root"/smoke_test_*.txt; do
    [ -f "$f" ] || continue
    t=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")
    if [ "$t" -ge "$start" ] && [ "$t" -ge "$newest_t" ]; then newest="$f"; newest_t=$t; fi
  done
  [ -n "$newest" ] && echo "$newest"
}

# smoke_test_X.txt -> smoke_<kind>_X.txt; any other name -> name.<kind>.txt
sibling() {
  local dir base; dir="$(dirname "$1")"; base="$(basename "$1" .txt)"
  case "$base" in
    smoke_test_*) echo "$dir/smoke_$2_${base#smoke_test_}.txt" ;;
    *)            echo "$dir/$base.$2.txt" ;;
  esac
}

signal_text() {
  case "$1" in
    SEGV) echo "segmentation fault" ;;   KILL) echo "killed, for example by the out-of-memory killer" ;;
    TERM) echo "terminated" ;;           INT)  echo "interrupted" ;;
    HUP)  echo "hangup, the terminal closed" ;; ABRT) echo "aborted" ;;
    BUS)  echo "bus error" ;;            ILL)  echo "illegal instruction" ;;
    FPE)  echo "floating-point exception" ;; PIPE) echo "broken pipe" ;;
    *)    echo "signal" ;;
  esac
}

tmpconsole="$(mktemp "${TMPDIR:-/tmp}/stem_smoke_console.XXXXXX")"
wolframscript -file "$here/smoke_test.wl" -- "$@" > >(tee "$tmpconsole") 2>&1 &
pid=$!

report=""; console=""; heartbeat=""
while kill -0 "$pid" 2>/dev/null; do
  [ -z "$report" ] && report="$(report_path)"
  if [ -n "$report" ]; then
    heartbeat="$(sibling "$report" heartbeat)"
    app="$(grep -o 'running [^ ]*' "$tmpconsole" 2>/dev/null | tail -1 | cut -d' ' -f2)"
    printf '%s alive, %d s since the start; running %s (wolframscript pid %d)\n' \
      "$(date '+%Y-%m-%d %H:%M:%S')" "$(( $(date +%s) - start ))" "${app:-the environment checks}" "$pid" \
      > "$heartbeat"
  fi
  for i in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
done
wait "$pid"; code=$?
sleep 1   # let tee finish

end_hm="$(date '+%H:%M')"; secs=$(( $(date +%s) - start ))
[ -z "$report" ] && report="$(report_path)"
if [ -z "$report" ]; then
  report="$root/smoke_wrapper_$(date '+%Y-%m-%d_%H%M').txt"
  echo "No report was written by this run; the wrapper's line goes to $report." | tee -a "$report"
fi
console="$(sibling "$report" console)"; cp "$tmpconsole" "$console"; rm -f "$tmpconsole"
heartbeat="$(sibling "$report" heartbeat)"

if grep -q '^Summary: ' "$report"; then
  line="The smoke test process ended at $end_hm."
else
  how="with exit code $code"
  if [ "$code" -gt 128 ]; then
    name="$(kill -l $(( code - 128 )) 2>/dev/null)"; name="${name#SIG}"
    [ -n "$name" ] && how="$how (SIG$name, $(signal_text "$name"))"
  fi
  line="The smoke test process ended at $end_hm $how after $secs s."
fi
echo "$line" >> "$report"
printf '%s ended: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line" > "$heartbeat"
echo "$line"
echo "Report: $report"
exit "$code"
