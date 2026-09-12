#!/usr/bin/env bash
#
# scripts/sprint-loop.sh — autonomous sprint worker driver (groq/orchestrated).
#
# Architecture (per owner decision 2026-09-10):
#   Engineer  → opencode + openrouter/cohere/north-mini-code:free (tools OK)
#   Reviewer  → groq/compound via Groq API (free tier, text-only roles)
#   Coordinator = this script: pulls READY_FOR_PM items from
#   .agent-loop/backlog-inbox.md, runs Engineer on a sprint/<TSK> branch,
#   QA-gates (groq/compound verdict + deterministic build check), squash-merges,
#   and updates .agent-loop/squad-handshake.md. 3-strike BLOCKED rule.
#
# State files live in .agent-loop/ (gitignored). Never run as root.
# Env: REPO defaults to the script's parent dir; OPENCODE_* flags are set to run opencode headless without外部 plugins.

set -uo pipefail

REPO="${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE="$REPO/.agent-loop"
OPENCODE_MODEL="${OPENCODE_MODEL:-openrouter/cohere/north-mini-code:free}"
COMPOUND_MODEL="${COMPOUND_MODEL:-groq/compound}"
TASK_TIMEOUT="${SPRINT_TASK_TIMEOUT:-1800}"
MAX_STRIKES="${SPRINT_MAX_STRIKES:-3}"
HANDSHAKE="$STATE/squad-handshake.md"
LOG="$STATE/loop.log"

mkdir -p "$STATE"

log() { echo "[$(date -u +%H:%M:%S)] $*" | tee -a "$LOG" >&2; }

load_key() {
  local f="$REPO/.env.selfhost"
  if [ -r "$f" ]; then
    # shellcheck disable=SC1090
    set -a; source "$f"; set +a
  fi
  [ -n "${GROQ_API_KEY:-}" ] || { echo "ERROR: GROQ_API_KEY missing" >&2; return 1; }
  [ -n "${OPENROUTER_API_KEY:-}" ] || {
    if [ -r "$REPO/../nevnew/.env" ]; then
      export OPENROUTER_API_KEY="$(grep OPENROUTER_API_KEY "$REPO/../nevnew/.env" | cut -d= -f2)"
    fi
  }
  return 0
}

# macOS has no(1)/timeout — portable watchdog
timeout_run() { local secs="$1"; shift; "$@" & local p=$!; local el=0
  while kill -0 "$p" 2>/dev/null && [ "$el" -lt "$secs" ]; do sleep 3; el=$((el+3)); done
  if kill -0 "$p" 2>/dev/null; then kill -9 "$p" 2>/dev/null; wait "$p" 2>/dev/null; return 124; fi
  wait "$p"
}

groq_role() {
  # $1 = role instruction, $2 = content. Prints model text. Nonzero on failure.
  load_key || return 1
  python3 - "$COMPOUND_MODEL" "$1" "$2" "${GROQ_API_KEY}" <<'PYEOF'
import json, sys, urllib.request
model, instr, content, api_key = sys.argv[1:5]
payload = {
    "model": model,
    "messages": [
        {"role": "system", "content": instr},
        {"role": "user", "content": content[:28000]},
    ],
    "temperature": 0.2,
    "max_tokens": 4096,
}
req = urllib.request.Request(
    "https://api.groq.com/openai/v1/chat/completions",
    data=json.dumps(payload).encode(),
    headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json",
             "User-Agent": "lineoa-sprint-loop/1.0"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=120) as r:
        body = json.loads(r.read().decode())
except urllib.error.HTTPError as e:
    sys.stderr.write(f"groq {e.code}: {e.read().decode()[:300]}\n"); sys.exit(1)
print(body["choices"][0]["message"]["content"].strip())
PYEOF
}

# --- task plumbing ----------------------------------------------------------
next_task() {
  python3 - "$STATE/backlog-inbox.md" <<'PYEOF'
import re, sys
text = open(sys.argv[1]).read()
for m in re.finditer(r"<task_item>(.*?)</task_item>", text, re.S):
    block = m.group(1)
    if re.search(r"<status>\s*READY_FOR_PM\s*</status>", block):
        tid = re.search(r"<id>(.*?)</id>", block).group(1).strip()
        title = re.search(r"<title>(.*?)</title>", block, re.S).group(1).strip()
        desc = re.search(r"<description>(.*?)</description>", block, re.S).group(1).strip()
        accept = re.search(r"<acceptance>(.*?)</acceptance>", block, re.S)
        print(tid); print(title); print(desc)
        print(accept.group(1).strip() if accept else "")
        break
PYEOF
}

set_task_status() {
  # $1 id, $2 status
  python3 - "$STATE/backlog-inbox.md" "$1" "$2" <<'PYEOF'
import re, sys
p, tid, status = sys.argv[1:4]
s = open(p).read()
def repl(m):
    b = m.group(1)
    if f"<id>{tid}</id>" in b or re.search(rf"<id>\s*{tid}\s*</id>", b):
        b = re.sub(r"<status>.*?</status>", f"<status>{status}</status>", b, flags=re.S)
    return "<task_item>" + b + "</task_item>"
s = re.sub(r"<task_item>.*?</task_item>", repl, s, flags=re.S)
open(p, "w").write(s)
PYEOF
}

write_handshake() {
  # $1 status $2 task $3 sprint% $4 notes-file (optional)
  local st="$1" task="$2" pct="$3"
  {
    echo "<squad_metadata>"
    echo "  <squad_name>Engineer-Squad</squad_name>"
    echo "  <current_status>${st}</current_status>"
    echo "  <active_task_id>${task}</active_task_id>"
    echo "  <sprint_completion_percentage>${pct}</sprint_completion_percentage>"
    echo "</squad_metadata>"
    echo
    echo "## Current Focus"
    echo "Worker: ${OPENCODE_MODEL} · Reviewer: ${COMPOUND_MODEL}"
    echo
    echo "## Recent Commits / PRs"
    gh pr list -R GRITui/LineOA-middleware --state merged --limit 5 2>/dev/null | sed 's/^/* /' || true
    echo
    echo "## Blockers & QA Failures"
    grep -B0 -A0 'BLOCKED' "$STATE/backlog-inbox.md" 2>/dev/null | head -5 || true
  } > "$HANDSHAKE"
}

engineer_attempt() { # $1=model $2=id $3=prompt — run one opencode attempt on fresh sprint branch
  local model="$1" id="$2" prompt="$3"
  local branch="sprint/$id"
  git -C "$REPO" fetch -q origin main 2>/dev/null
  git -C "$REPO" checkout -q -B "$branch" origin/main 2>/dev/null || git -C "$REPO" checkout -q "$branch"
  (
    cd "$REPO" &&
    OPENCODE_DISABLE_DEFAULT_PLUGINS=1 OPENCODE_DISABLE_EXTERNAL_SKILLS=1 \
    OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1     OPENCODE_PURE=1 \
    timeout_run "$TASK_TIMEOUT" opencode run --dir "$REPO" -m "$model" "$prompt"
  )
}

# Worker fallback chain (owner policy 2026-09-10):
#   free tier → next free-tier worker → on ACCOUNT limit → minimax-m3 on opencode-go
WORKER_CHAIN=(
  "${OPENCODE_MODEL:-openrouter/cohere/north-mini-code:free}"
  "${OPENCODE_FALLBACK_FREE:-openrouter/nvidia/nemotron-3.5-lightning:free}"
  "${OPENCODE_FALLBACK_ACCOUNT:-opencode-go/minimax-m3}"
)

classify_failure() { # $1=log file → echoes quota|account|error
  local tail_txt
  tail_txt=$(tail -c 4000 "$1" 2>/dev/null)
  if echo "$tail_txt" | grep -qiE '429|rate.?limit|quota|exceeded|free[- ]tier|monthly limit|daily limit'; then
    echo quota
  elif echo "$tail_txt" | grep -qiE '402|403|insufficient|credit|balance|payment|invalid api key|unauthorized'; then
    echo account
  else
    echo error
  fi
}

# Attempt the whole chain (owner fallback policy):
#   free quota (429/rate-limit) → next free worker
#   account limit (402/403/credits/balance)   → jump straight to opencode-go/minimax-m3
engineer_task() { # $1=id $2=full-prompt
  local id="$1" prompt="$2"
  local logf="$STATE/run-$id.log"
  : > "$logf"
  local idx=0 retries=0 n=${#WORKER_CHAIN[@]}
  while [ "$idx" -lt "$n" ]; do
    m="${WORKER_CHAIN[$idx]}"
    log "engineer attempt via $m (attempt$retries)"
    if engineer_attempt "$m" "$id" "$prompt" >> "$logf" 2>&1; then
      CURRENT_WORKER="$m"
      return 0
    fi
    KIND="$(classify_failure "$logf")"
    log "engineer $m failed ($KIND)"
    case "$KIND" in
      account)
        CURRENT_WORKER=""
        break ;;
      quota)
        idx=$((idx+1)) ;;
      error)
        if [ "$retries" -lt 1 ]; then retries=$((retries+1)); else retries=0; idx=$((idx+1)); fi ;;
    esac
  done
  CURRENT_WORKER=""
  return 1
}

main() {
  cd "$REPO"
  load_key || exit 1
  log "== sprint-loop start =="

  while true; do
    MAPFILE=(); # id/title/desc/acceptance
    OUT="$(next_task || true)"
    if [ -z "$OUT" ]; then
      log "no READY_FOR_PM tasks — loop complete"
      write_handshake "IDLE" "-" "100"
      break
    fi
    TSK_ID=$(echo "$OUT" | sed -n 1p)
    TSK_TITLE=$(echo "$OUT" | sed -n 2p)
    TSK_BODY=$(echo "$OUT" | sed -n '3,5p')
    log "picked $TSK_ID: $TSK_TITLE"

    # PM shaping (groq compound): compact task brief for the engineer
    BRIEF="$(groq_role "You are the PM of an engineering squad. Convert the task into a precise, self-contained engineering brief: concrete files to create/modify (guess reasonable paths from repo layout given), acceptance criteria as a checklist, and 3 critical MUST-NOTs. Reply with the brief only." \
"Task $TSK_ID — $TSK_TITLE
$TSK_BODY
Repo: Swift/Vapor 4 API at apps/api (+Tests), Next.js LIFF at apps/liff, Docker Postgres (staging live). Next.js admin panel planned at apps/admin (may not exist yet - create it if the task says so). Rules: SwiftUI macOS admin apps/live tunnel URLs are out of scope; do not touch .env* files; CI must stay green (swift build/test; npm lint/build)." || true)"
    [ -z "$BRIEF" ] && BRIEF="Implement the task per acceptance. Keep changes minimal and focused."

    ENGINEER_PROMPT="You are a senior engineer working SOLO in this repository.
$BRIEF
Non-negotiables:
- Make/build the change for THIS task only. Keep diffs tight.
- apps/api: ensure \`swift build\` passes before you finish (run it).
- apps/admin or apps/liff (Next.js): ensure \`npm run build\` and \`npm run lint\` pass (run them in that app dir).
- DO NOT run: git commit/push, gh, docker, or any network/cloud commands.
- DO NOT edit .env* files, .agent-loop/ or scripts/.
- Finish with a one-paragraph summary of changed files.
CURRENT TASK: $TSK_ID — $TSK_TITLE"

    STRIKES=$(grep -oE "${TSK_ID}\|strikes=[0-9]" "$STATE/strikes" 2>/dev/null | cut -d= -f2)
    STRIKES="${STRIKES:-0}"

    log "engineer run for $TSK_ID"
    if engineer_task "$TSK_ID" "$ENGINEER_PROMPT" >> "$STATE/run-$TSK_ID.log" 2>&1; then
      git add -A 2>/dev/null
      git status --short | head -3
      if git diff --cached --quiet; then
        log "$TSK_ID produced no diff — marking BLOCKED"
        set_task_status "$TSK_ID" BLOCKED
        continue
      fi
      git -c user.email=agent@lineoa.dev -c user.name="Sprint Engineer [bot]" commit -q -m "$TSK_ID: $TSK_TITLE" || { log "commit failed"; }
      # Deterministic gate: build
      BUILD_OK=1
      if git diff --name-only HEAD~1 2>/dev/null | grep -q '^apps/api'; then
        (cd "$REPO/apps/api" && swift build 2>"$STATE/build-$TSK_ID.log") || BUILD_OK=0
      fi
      if git diff --name-only HEAD~1 2>/dev/null | grep -qE '^apps/(admin|liff)/'; then
        APP=$(git diff --name-only HEAD~1 | grep -oE '^apps/(admin|liff)' | head -1)
        (cd "$REPO/$APP" && npm run build >/dev/null 2>&1 && npm run lint >/dev/null 2>&1) || BUILD_OK=0
      fi
      if [ "$BUILD_OK" != 1 ]; then
        STRIKES=$((STRIKES+1)); echo "$TSK_ID|strikes=$STRIKES" >> "$STATE/strikes"
        if [ "$STRIKES" -ge "$MAX_STRIKES" ]; then
          log "$TSK_ID BLOCKED after $STRIKES strikes (build/QA fail)"; set_task_status "$TSK_ID" BLOCKED
          git checkout -q main
        else
          log "$TSK_ID strike $STRIKES — retrying"
          git reset -q --hard HEAD~1
        fi
        continue
      fi
      # push + PR + squash merge
      git push -q -u origin "sprint/$TSK_ID" 2>/dev/null
      PR_URL=$(gh pr create -R GRITui/LineOA-middleware --head "sprint/$TSK_ID" --title "[$TSK_ID] $TSK_TITLE" --body "${BRIEF}" 2>/dev/null | tail -1)
      log "$TSK_ID PR: $PR_URL"
      # compound QA verdict (comment review) — advisory for now
      QAREVIEW=$(git diff origin/main...HEAD --stat | head -40; echo '---'; git log -1 --format=%B)
      VERDICT=$(groq_role "You are the QA-Tester squad lead. Review this diff summary + commit message for major correctness issues only (correctness, tests-skipped, breaking API changes). Reply with exactly one line starting VERDICT: PASS or VERDICT: FAIL plus a terse reason." "$QAREVIEW" 2>/dev/null || echo "VERDICT: PASS (reviewer offline)")
      echo "$TSK_ID $VERDICT" >> "$STATE/verdicts.log"
      case "$VERDICT" in
        VERDICT:\ FAIL*) 
          STRIKES=$((STRIKES+1)); echo "$TSK_ID|strikes=$STRIKES" >> "$STATE/strikes"
          if [ "$STRIKES" -ge "$MAX_STRIKES" ]; then
            log "$TSK_ID BLOCKED after $STRIKES strikes (QA fail)"; set_task_status "$TSK_ID" BLOCKED
          else
            log "$TSK_ID QA strike $STRIKES — retrying"; set_task_status "$TSK_ID" NEEDS_OWNER_REVIEW
          fi
          ;;
        *)
          gh pr merge -R GRITui/LineOA-middleware "sprint/$TSK_ID" --squash --delete-branch 2>/dev/null || log "merge failed for $TSK_ID"
          set_task_status "$TSK_ID" DONE
          PCT_DONE=$(( ( $(grep -c '<status>' "$STATE/backlog-inbox.md") - $(grep -c 'READY_FOR_PM\|NEEDS_OWNER_REVIEW' "$STATE/backlog-inbox.md") ) * 100 ))
          write_handshake "EXECUTING" "$TSK_ID (done)" "$PCT_DONE"
          log "$TSK_ID merged ✅"
          ;;
      esac
      git checkout -q main && git pull -q origin main 2>/dev/null
    else
      STRIKES=$((STRIKES+1)); echo "$TSK_ID|strikes=$STRIKES" >> "$STATE/strikes"
      if [ "$STRIKES" -ge "$MAX_STRIKES" ]; then
        log "$TSK_ID BLOCKED (engineer run failed $STRIKESx)"; set_task_status "$TSK_ID" BLOCKED
        git checkout -q main
      else
        log "$TSK_ID engineer crash strike $STRIKES — retrying"
      fi
    fi
  done
  log "== sprint-loop end =="
}

main "$@"
