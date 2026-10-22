#!/usr/bin/env bash
# Is a power domain really powered off during a cycle? /sys/kernel/debug/pm_genpd/<d>/active_time only grows while
# the domain is ON (pmdomain/core.c genpd_update_accounting adds the elapsed delta to on_time when status is OFF),
# so delta(active_time) << delta(wall) proves it dropped in between. This answers the F9/F10 question ("does the
# system-suspend path drop mdss_gdsc while the DPMS path does not") with no kernel rebuild: pm_genpd_summary
# cannot be sampled mid-suspend (no FTRACE, and /sys/power/pm_freeze_processes is gone in 7.2).
# total_idle_time is useless here: it loops over genpd->states, and these domains have no DT idle states.
#
# usage: scripts/genpd-cycle.sh '<command run on the tablet>' ['<next command>' ...]
# One sample table is printed before each command and one at the end, with the per-step deltas.
M=/home/USER/External/work/src/mainline
cd $M || exit 1
DOM=${DOMAINS:-"mdss_gdsc mdss_int2_gdsc gpu_cc_gx_gdsc"}
DPMS=${DPMS:-/sys/class/drm/card1-DSI-1/dpms}
REMOTE='for d in '"$DOM"'; do printf "%s %s %s %s %s\n" "$(date +%s%3N)" "$d" "$(cat /sys/kernel/debug/pm_genpd/$d/current_state)" "$(tr -dc 0-9 < /sys/kernel/debug/pm_genpd/$d/active_time)" "$(cat '"$DPMS"' 2>/dev/null)"; done'

diff_() {
  paste <(echo "$1") <(echo "$2") | awk '{off=$6-$1-($9-$4);
    printf "  %-16s %s -> %s  dpms %s -> %s  active_time +%-8d ms  wall +%-8d ms  %s\n", $2, $3, $8, $5, $10, $9-$4, $6-$1,
      (off > 1000 ? "POWERED OFF for " off " ms" : "stayed on")}'
}

first=$(scripts/rssh.sh "$REMOTE"); prev=$first; echo "$first"
for c in "$@"; do
  echo "== $c"; scripts/rssh.sh "$c"
  cur=$(scripts/rssh.sh "$REMOTE"); echo "$cur"; diff_ "$prev" "$cur"; prev=$cur
done
echo "== total"
diff_ "$first" "$prev"
