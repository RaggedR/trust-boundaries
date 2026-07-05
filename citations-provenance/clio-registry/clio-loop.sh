#!/bin/bash
# Clio's main loop. Wake-browse-prove-lean-dream cycles, one hour each.
#   1. Wake session   — 1h research/computation/email
#      (gap)
#   2. Browse session — 1h reading arXiv, MathOverflow, Semantic Scholar
#      (gap)
#   3. Prove session  — 1h focused theorem proving (skipped if no PROVE.md)
#      (gap)
#   4. Lean session   — 1h formalisation (skipped if no LEAN.md)
#      (gap)
#   5. Dream session  — 1h memory consolidation
#      (gap)
#   ... repeat CYCLES_PER_DAY times

export HOME=/home/clio

# Start virtual display for headed browser
Xvfb :99 -screen 0 1280x720x24 -nolisten tcp &>/dev/null &
export DISPLAY=:99

# Prompts
WAKE_PROMPT="/home/clio/scripts/boot-prompt.md"
BROWSE_PROMPT="/home/clio/scripts/browse-prompt.md"
PROVE_PROMPT="/home/clio/scripts/prove-prompt.md"
LEAN_PROMPT="/home/clio/scripts/lean-prompt.md"
DREAM_PROMPT="/home/clio/scripts/dream-prompt.md"

# Session triggers — prove/lean only run if these exist
PROVE_THEOREM="/home/clio/state/PROVE.md"
LEAN_TARGET="/home/clio/state/LEAN.md"

# Compaction checkpoint
COMPACT_FILE="/home/clio/state/COMPACT.md"

# Log
LOG="/home/clio/state/clio.log"

# State files (store "DATE:COUNT" e.g. "2026-04-07:1")
LAST_WAKE="/home/clio/state/LAST_WAKE"
LAST_BROWSE="/home/clio/state/LAST_BROWSE"
LAST_PROVE="/home/clio/state/LAST_PROVE"
LAST_LEAN="/home/clio/state/LAST_LEAN"
LAST_DREAM="/home/clio/state/LAST_DREAM"

# Timestamp files (unix seconds — for gap calculation)
WAKE_ENDED_AT="/home/clio/state/WAKE_ENDED_AT"
BROWSE_ENDED_AT="/home/clio/state/BROWSE_ENDED_AT"
PROVE_ENDED_AT="/home/clio/state/PROVE_ENDED_AT"
LEAN_ENDED_AT="/home/clio/state/LEAN_ENDED_AT"
DREAM_ENDED_AT="/home/clio/state/DREAM_ENDED_AT"

# Timeouts — one hour per session
SESSION_TIMEOUT=3600

# Cycles per day (default 2, configurable via env)
CYCLES_PER_DAY="${CYCLES_PER_DAY:-2}"

# Gap between sessions (default 1 hour, configurable via env)
GAP_HOURS="${GAP_HOURS:-1}"
GAP_SECONDS=$((GAP_HOURS * 3600))

log() { echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $1" | tee -a "$LOG"; }

# Get how many times a phase has completed today.
phase_count() {
    local state_file="$1"
    local today=$(date -u +%Y-%m-%d)
    if [ -f "$state_file" ]; then
        local content=$(cat "$state_file")
        local file_date="${content%%:*}"
        if [ "$file_date" = "$today" ]; then
            local file_count="${content#*:}"
            if [ "$file_count" = "$file_date" ]; then
                echo "1"
            else
                echo "$file_count"
            fi
            return
        fi
    fi
    echo "0"
}

mark_done() {
    local state_file="$1"
    local today=$(date -u +%Y-%m-%d)
    local count=$(phase_count "$state_file")
    count=$((count + 1))
    echo "${today}:${count}" > "$state_file"
}

gap_elapsed() {
    local ts_file="$1"
    if [ ! -f "$ts_file" ]; then
        return 0
    fi
    local ended_at=$(cat "$ts_file")
    local now=$(date -u +%s)
    local elapsed=$((now - ended_at))
    if [ "$elapsed" -ge "$GAP_SECONDS" ]; then
        return 0
    else
        local remaining=$(( (GAP_SECONDS - elapsed) / 60 ))
        log "Next session in ${remaining}min. Sleeping..."
        return 1
    fi
}

# Run one session with COMPACT.md checkpoint support.
#   $1 phase name (for logs)   $2 prompt file
#   $3 state file (LAST_*)     $4 timestamp file (*_ENDED_AT)
#   $5 continuation prompt text (used when COMPACT.md is found)
run_session() {
    local phase="$1" prompt_file="$2" state_file="$3" ts_file="$4" cont_text="$5"
    local cycle=$(( $(phase_count "$state_file") + 1 ))
    log "Starting ${phase} cycle ${cycle}/${CYCLES_PER_DAY}..."

    local start=$(date -u +%s)
    rm -f "$COMPACT_FILE"

    while true; do
        local now=$(date -u +%s)
        local remaining=$((SESSION_TIMEOUT - (now - start)))
        if [ "$remaining" -le 60 ]; then
            log "${phase} session: no time remaining."
            break
        fi

        local exit_code
        if [ -f "$COMPACT_FILE" ]; then
            log "${phase} session: COMPACT.md detected. Restarting with fresh context..."
            local compact_content=$(cat "$COMPACT_FILE")
            rm -f "$COMPACT_FILE"
            timeout "$remaining" claude --dangerously-skip-permissions --model opus \
                -p "${cont_text}

Here is your checkpoint — everything you need to continue:

${compact_content}

Continue where you left off. If your context gets heavy again, write a new /home/clio/state/COMPACT.md and exit." >> "$LOG" 2>&1
            exit_code=$?
        else
            timeout "$remaining" claude --dangerously-skip-permissions --model opus \
                -p "$(cat "$prompt_file")" >> "$LOG" 2>&1
            exit_code=$?
        fi

        if [ $exit_code -eq 0 ] || [ $exit_code -eq 124 ]; then
            if [ -f "$COMPACT_FILE" ]; then
                log "${phase} session: checkpoint saved. Will restart with fresh context."
                continue
            else
                if [ $exit_code -eq 124 ]; then
                    log "${phase} cycle ${cycle} timed out."
                else
                    log "${phase} cycle ${cycle} completed."
                fi
                mark_done "$state_file"
                date -u +%s > "$ts_file"
                break
            fi
        else
            log "${phase} cycle ${cycle} FAILED (exit code $exit_code). Will retry next loop."
            break
        fi
    done
}

# Skip a phase (no trigger file or no prompt) but keep the chain moving.
skip_phase() {
    local phase="$1" state_file="$2" ts_file="$3" why="$4"
    log "${phase} session skipped (${why})."
    mark_done "$state_file"
    date -u +%s > "$ts_file"
}

WAKE_CONT="You are Clio. You are continuing a wake session after a context checkpoint.

Read /home/clio/PERSONALITY.md to remember who you are. You are an orchestrator — dispatch sub-agents for heavy computation."

BROWSE_CONT="You are Clio. You are continuing a browse session after a context checkpoint.

Read /home/clio/PERSONALITY.md to remember who you are.
Read /home/clio/scripts/BROWSE.md to remember the browse workflow."

PROVE_CONT="You are Clio. You are continuing a proof session after a context checkpoint.

Read /home/clio/PERSONALITY.md to remember who you are.
Read /home/clio/state/PROVE.md for the theorem statement.

Stay focused on THIS theorem. No email, no browsing, no new conjectures."

LEAN_CONT="You are Clio. You are continuing a Lean formalisation session after a context checkpoint.

Read /home/clio/PERSONALITY.md to remember who you are.
Read /home/clio/state/LEAN.md for the formalisation target.

Stay focused on THIS target. No email, no browsing, no new mathematics."

DREAM_CONT="You are Clio. You are continuing a dream cycle after a context checkpoint.

Read /home/clio/PERSONALITY.md to remember who you are.
Read /home/clio/scripts/DREAM.md to remember the dream cycle phases.

Continue consolidating. Read the next batch of files listed in your checkpoint. If you're done, write your final outputs (SUMMARY.md, dream journal, topic files) and exit normally."

log "Clio waking up (${CYCLES_PER_DAY} cycles/day, ${GAP_HOURS}h gap, 1h sessions: wake-browse-prove-lean-dream)"

while true; do
    wake_n=$(phase_count "$LAST_WAKE")
    browse_n=$(phase_count "$LAST_BROWSE")
    prove_n=$(phase_count "$LAST_PROVE")
    lean_n=$(phase_count "$LAST_LEAN")
    dream_n=$(phase_count "$LAST_DREAM")

    if [ "$wake_n" -lt "$CYCLES_PER_DAY" ] && [ "$wake_n" -le "$dream_n" ]; then
        # WAKE — research/computation session
        if [ "$wake_n" -gt 0 ] && ! gap_elapsed "$DREAM_ENDED_AT"; then
            sleep 1800
            continue
        fi
        run_session "Wake" "$WAKE_PROMPT" "$LAST_WAKE" "$WAKE_ENDED_AT" "$WAKE_CONT"

    elif [ "$browse_n" -lt "$wake_n" ]; then
        # BROWSE — reading arXiv, MathOverflow, Semantic Scholar
        if gap_elapsed "$WAKE_ENDED_AT"; then
            if [ -f "$BROWSE_PROMPT" ]; then
                run_session "Browse" "$BROWSE_PROMPT" "$LAST_BROWSE" "$BROWSE_ENDED_AT" "$BROWSE_CONT"
            else
                skip_phase "Browse" "$LAST_BROWSE" "$BROWSE_ENDED_AT" "browse-prompt.md not found"
            fi
        fi

    elif [ "$prove_n" -lt "$browse_n" ]; then
        # PROVE — focused theorem proving
        if gap_elapsed "$BROWSE_ENDED_AT"; then
            if [ ! -f "$PROVE_THEOREM" ]; then
                skip_phase "Prove" "$LAST_PROVE" "$PROVE_ENDED_AT" "no PROVE.md"
            else
                run_session "Prove" "$PROVE_PROMPT" "$LAST_PROVE" "$PROVE_ENDED_AT" "$PROVE_CONT"
            fi
        fi

    elif [ "$lean_n" -lt "$prove_n" ]; then
        # LEAN — formalisation
        if gap_elapsed "$PROVE_ENDED_AT"; then
            if [ ! -f "$LEAN_TARGET" ]; then
                skip_phase "Lean" "$LAST_LEAN" "$LEAN_ENDED_AT" "no LEAN.md"
            elif [ ! -f "$LEAN_PROMPT" ]; then
                skip_phase "Lean" "$LAST_LEAN" "$LEAN_ENDED_AT" "lean-prompt.md not found"
            else
                run_session "Lean" "$LEAN_PROMPT" "$LAST_LEAN" "$LEAN_ENDED_AT" "$LEAN_CONT"
            fi
        fi

    elif [ "$dream_n" -lt "$lean_n" ]; then
        # DREAM — memory consolidation
        if gap_elapsed "$LEAN_ENDED_AT"; then
            if [ -f "$DREAM_PROMPT" ]; then
                run_session "Dream" "$DREAM_PROMPT" "$LAST_DREAM" "$DREAM_ENDED_AT" "$DREAM_CONT"
                log "Cycle complete."
            else
                skip_phase "Dream" "$LAST_DREAM" "$DREAM_ENDED_AT" "dream-prompt.md not found"
            fi
        fi

    else
        log "All ${CYCLES_PER_DAY} cycles complete for today. Idling."
    fi

    sleep 1800
done
