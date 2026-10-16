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
# - It passes an explicit --out=<report> (see below), so the end line
#   always lands in this run's own report.
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

# The report this run writes, fixed before the start and passed to the
# smoke test as --out, so the end line can only land in this run's report
# (looking for "the newest report" put a second run's end line into the
# first run's report on 2026-10-16):
# - --out=<path> given: that path;
# - --resume: the newest smoke_test_<SystemID>_*.txt, the one smoke_test.wl
#   would pick itself;
# - otherwise smoke_test_<SystemID>_<date>_<HHMM>.txt from the start time
#   (with _2, _3 ... if a run in the same minute already used the name).
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64)         sysid=MacOSX-ARM64 ;;
  Darwin/x86_64)        sysid=MacOSX-x86-64 ;;
  Linux/x86_64)         sysid=Linux-x86-64 ;;
  Linux/aarch64|Linux/arm64) sysid=Linux-ARM64 ;;
  *)                    sysid="$(uname -s)-$(uname -m)" ;;
esac
out=""; resume=0; pass=()
for a in "$@"; do
  case "$a" in
    --out=*) out="${a#--out=}" ;;
    --resume) resume=1; pass+=("$a") ;;
    *) pass+=("$a") ;;
  esac
done
if [ -z "$out" ] && [ "$resume" = 1 ]; then
  out="$(ls -t "$root"/smoke_test_"$sysid"_*.txt 2>/dev/null | head -1)"
  [ -z "$out" ] && { echo "--resume: no smoke_test_${sysid}_*.txt in $root to resume." >&2; exit 1; }
fi
if [ -z "$out" ]; then
  out="$root/smoke_test_${sysid}_$(date -r "$start" '+%Y-%m-%d_%H%M' 2>/dev/null || date -d "@$start" '+%Y-%m-%d_%H%M').txt"
  n=2; base="${out%.txt}"
  while [ -e "$out" ]; do out="${base}_$n.txt"; n=$((n + 1)); done
fi
pass+=("--out=$out")

report_path() { [ -f "$out" ] && echo "$out"; }

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
wolframscript -file "$here/smoke_test.wl" -- "${pass[@]}" > >(tee "$tmpconsole") 2>&1 &
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
if [ ! -f "$out" ]; then
  echo "No report was written by this run; the wrapper's line goes to $out." | tee -a "$out"
fi
report="$out"
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
