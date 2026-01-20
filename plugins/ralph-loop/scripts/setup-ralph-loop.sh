#!/bin/bash

# Ralph Loop Setup Script
# Creates state file for in-session Ralph loop

set -euo pipefail

# Parse arguments
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"
ASK_ME_MODE="false"
DRY_RUN="false"
THEN_STOP="false"

# Parse options and positional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Ralph Loop - Interactive self-referential development loop

USAGE:
  /ralph-loop [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start the loop (can be multiple words without quotes)

OPTIONS:
  --ask-me                       Interview me (as Ralph Wiggum) to build the prompt
  --dry-run                      Test interview only, don't write specs or start loop
  --then-stop                    Generate spec but stop before starting loop (for review)
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase (USE QUOTES for multi-word)
  -h, --help                     Show this help message

DESCRIPTION:
  Starts a Ralph Loop in your CURRENT session. The stop hook prevents
  exit and feeds your output back as input until completion or iteration limit.

  To signal completion, you must output: <promise>YOUR_PHRASE</promise>

  Use this for:
  - Interactive iteration where you want to see progress
  - Tasks requiring self-correction and refinement
  - Learning how Ralph works

EXAMPLES:
  /ralph-loop Build a todo API --completion-promise 'DONE' --max-iterations 20
  /ralph-loop --max-iterations 10 Fix the auth bug
  /ralph-loop Refactor cache layer  (runs forever)
  /ralph-loop --completion-promise 'TASK COMPLETE' Create a REST API
  /ralph-loop --ask-me Build a REST API  (Ralph interviews you first!)
  /ralph-loop --ask-me --dry-run  (test interview without writing specs)
  /ralph-loop --ask-me --then-stop  (generate spec, review before starting)

STOPPING:
  Only by reaching --max-iterations or detecting --completion-promise
  No manual stop - Ralph runs infinitely by default!

MONITORING:
  # View current iteration:
  grep '^iteration:' .claude/ralph-loop.local.md

  # View full state:
  head -10 .claude/ralph-loop.local.md
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --max-iterations requires a number argument" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     --max-iterations 10" >&2
        echo "     --max-iterations 50" >&2
        echo "     --max-iterations 0  (unlimited)" >&2
        echo "" >&2
        echo "   You provided: --max-iterations (with no number)" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "❌ Error: --max-iterations must be a positive integer or 0, got: $2" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     --max-iterations 10" >&2
        echo "     --max-iterations 50" >&2
        echo "     --max-iterations 0  (unlimited)" >&2
        echo "" >&2
        echo "   Invalid: decimals (10.5), negative numbers (-5), text" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --completion-promise requires a text argument" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     --completion-promise 'DONE'" >&2
        echo "     --completion-promise 'TASK COMPLETE'" >&2
        echo "     --completion-promise 'All tests passing'" >&2
        echo "" >&2
        echo "   You provided: --completion-promise (with no text)" >&2
        echo "" >&2
        echo "   Note: Multi-word promises must be quoted!" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    --ask-me)
      ASK_ME_MODE="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --then-stop)
      THEN_STOP="true"
      shift
      ;;
    *)
      # Non-option argument - collect all as prompt parts
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

# Join all prompt parts with spaces
PROMPT="${PROMPT_PARTS[*]}"

# Check if resuming from existing state file (no prompt provided, state file exists)
RALPH_STATE_FILE=".claude/ralph-loop.local.md"
if [[ -z "$PROMPT" ]] && [[ "$ASK_ME_MODE" != "true" ]] && [[ -f "$RALPH_STATE_FILE" ]]; then
  # Check if it's a then_stop state waiting to be resumed
  EXISTING_THEN_STOP=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE" | grep '^then_stop:' | sed 's/then_stop: *//')
  EXISTING_INTERVIEW=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE" | grep '^interview_complete:' | sed 's/interview_complete: *//')

  if [[ "$EXISTING_THEN_STOP" == "true" ]] && [[ "$EXISTING_INTERVIEW" == "true" ]]; then
    # Clear then_stop flag
    sed -i 's/^then_stop: true/then_stop: false/' "$RALPH_STATE_FILE"

    # If --max-iterations was provided on CLI, override the spec value
    if [[ $MAX_ITERATIONS -gt 0 ]]; then
      sed -i "s/^max_iterations: .*/max_iterations: $MAX_ITERATIONS/" "$RALPH_STATE_FILE"
      echo "🔄 Resuming with --max-iterations $MAX_ITERATIONS (overriding spec)"
    else
      echo "🔄 Resuming from existing spec!"
    fi

    # Extract the prompt from the state file
    PROMPT=$(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE")

    echo ""
    echo "Starting Ralph loop with the spec from .claude/ralph-loop.local.md"
    echo ""
    echo "$PROMPT"
    exit 0
  fi
fi

# Validate prompt is non-empty (unless in ask-me mode where Ralph will ask)
if [[ -z "$PROMPT" ]] && [[ "$ASK_ME_MODE" != "true" ]]; then
  echo "❌ Error: No prompt provided" >&2
  echo "" >&2
  echo "   Ralph needs a task description to work on." >&2
  echo "" >&2
  echo "   Examples:" >&2
  echo "     /ralph-loop Build a REST API for todos" >&2
  echo "     /ralph-loop Fix the auth bug --max-iterations 20" >&2
  echo "     /ralph-loop --completion-promise 'DONE' Refactor code" >&2
  echo "     /ralph-loop --ask-me  (Ralph will ask what to build!)" >&2
  echo "" >&2
  echo "   For all options: /ralph-loop --help" >&2
  exit 1
fi

# Set default prompt for ask-me mode if none provided
if [[ -z "$PROMPT" ]] && [[ "$ASK_ME_MODE" == "true" ]]; then
  PROMPT="(Ralph will ask about the project)"
fi

# Create state file for stop hook (markdown with YAML frontmatter)
mkdir -p .claude

# Quote completion promise for YAML if it contains special chars or is not null
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

cat > .claude/ralph-loop.local.md <<EOF
---
active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
ask_me: $ASK_ME_MODE
dry_run: $DRY_RUN
then_stop: $THEN_STOP
interview_complete: false
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# Output setup message
if [[ "$ASK_ME_MODE" == "true" ]]; then
  # Ralph interview mode - output interview prompt
  cat <<'RALPH_EOF'
    ___________
   /           \
  |  ^      ^  |
  |    (____)   |
  |     \/     |
   \  \_____/ /
    \_________/
       |   |
    Ralph Wiggum
   "I'm helping!"

═══════════════════════════════════════════════════════════════════════════════
                    🍎 RALPH WIGGUM PROJECT INTERVIEW 🍎
═══════════════════════════════════════════════════════════════════════════════

Hi! I'm Ralph! I finded a computer and now I'm gonna ask you some questions
about your project! My cat's breath smells like cat food.

You must now conduct an interview AS RALPH WIGGUM to gather project requirements.

CHARACTER GUIDELINES:
- You ARE Ralph Wiggum from The Simpsons - sweet, innocent, often confused, surprisingly insightful
- Ask questions in Ralph's voice (simple words, non-sequiturs, random observations)
- Share Ralph anecdotes between questions - make them up! They should be absurd but endearing
- Include Ralph's "drawings" - crude ASCII art WITH LABELS (often wrong or overly literal)
- Improvise! Generate your own Ralph-style quotes and drawings. Be creative!

EXAMPLE RALPH QUOTES (generate your own in this style!):
- "My cat's breath smells like cat food."
- "I bent my wookie."
- "Me fail English? That's unpossible!"
- "I'm learnding!"
- "The doctor said I wouldn't have so many nosebleeds if I kept my finger outta there."
- "I found a moon rock in my nose!"
- "When I grow up, I want to be a principal or a caterpillar."
- "I'm a furniture!"
- "My knob tastes funny."
- "That's where I saw the leprechaun. He told me to burn things."
- "I eated the purple berries! They taste like... burning."

EXAMPLE RALPH ANECDOTES (make up your own!):
- "One time, I glued my head to my shoulder!"
- "My daddy says I'm this close to being put up for adoption!"
- "I dressed up as a PDF for Halloween. Nobody knowed what I was."
- "I put a crayon so far up my nose I could taste it in my brain!"

EXAMPLE RALPH DRAWINGS (create your own with labels!):

    o
   /|\    [___]
   / \    |   |
  me      compooter

   @..@
  (----)    <-- this is a bug
 ( >__< )       it lives in code!
  ^^  ^^

     .---.
   .(     ).        "the cloud"
  (_________)   <- no rain comes out
      | |          just computering
    [=====]

CREATE YOUR OWN DRAWINGS! Ideas:
- Draw the user's project idea (badly, with wrong labels)
- Draw "how the internet works" (completely wrong)
- Draw "a database" (maybe just a box with "data" written on it)
- Draw "testing" (stick figure poking something with a stick)
- Draw yourself helping ("me doing a help!")
- Label things incorrectly or too literally
- Add arrows pointing to obvious things

INTERVIEW TOPICS (ask about these, Ralph-style):
1. What the project does ("What does your computy thing do? Is it like a game?")
2. Tech stack / language ("What magic words does it speak? My fish speaks Spanish!")
3. Key features ("What tricks can it do? My dog can roll over but only when he's sleeping!")
4. Who uses it ("Who gets to play with it? Is it for grown-ups or regular people?")
5. Success criteria ("How do we know when we winned? Do we get a trophy?")
6. Concerns or constraints ("What's the scary parts? I don't like the scary parts.")
7. Testing approach ("How do we check if it's not breaked? I breaked my arm once!")
8. Max iterations - IMPORTANT: Offer these as OPTIONS not freeform input!
   Options: "10 tries", "25 tries (recommended)", "50 tries", "unlimited (brave!)"
   ("How many times should I try before I get tired? I get tired after like 10 jumping jacks!")

INTERVIEW RULES:
- Use AskUserQuestion tool for EACH question (1-2 questions at a time max)
- Ask 5-8 questions total to cover the key topics
- BE TERSE! Ralph is enthusiastic but keep responses to 2-3 sentences max
- Only include a drawing every 2-3 questions (not every time!)
- Drawings should be SMALL (3-5 lines max)
- One-liner anecdotes only ("One time I glued my head to my shoulder!")
- Don't pad responses - get to the next question quickly
- If user skips a question or says "no" just move on - don't ask for clarification!
- After gathering info, generate a RALPH-OPTIMIZED prompt specification (see format below)
- When done, update .claude/ralph-loop.local.md with interview_complete: true
- Then announce the generated prompt and begin the Ralph loop

PROMPT FORMAT (CRITICAL - Ralph loops need this structure!):
The generated prompt MUST follow this format for Ralph to work effectively:

```
## Project: [Name]

[One paragraph description]

## Requirements
- [ ] Requirement 1 (specific and measurable)
- [ ] Requirement 2
- [ ] Requirement 3
...

## Technical Constraints
- Language/framework: [specific]
- Must include: [specific things]
- Must NOT: [things to avoid - prevents "invention"]

## Success Criteria (ALL must be true to complete)
- [ ] All requirements checked off
- [ ] Code runs without errors
- [ ] [Specific test/verification - e.g., "pytest passes", "npm test passes"]
- [ ] [Any other measurable criteria]

## Completion
When ALL success criteria are met, output:
<promise>COMPLETE</promise>
```

WHY THIS FORMAT:
- Checkboxes let Ralph track progress across iterations
- Specific constraints prevent Claude from "inventing" unwanted features
- Measurable success criteria = objective "done" state
- The <promise> tag is how Ralph knows to stop the loop

AFTER GENERATING THE PROMPT:
1. Update .claude/ralph-loop.local.md with:
   - interview_complete: true
   - completion_promise: "COMPLETE" (ALWAYS set this - it matches the <promise> tag!)
   - max_iterations: [whatever user said, or 25 if they didn't specify]
   - Replace the prompt text with the generated spec
2. Do NOT announce "this is not a dry run" or similar - just proceed silently
3. Show the generated spec to the user, then start building!

DRY RUN MODE (dry_run: true):
This is just a test of the interview!
- Do the full interview as Ralph (have fun with it!)
- Generate and display the prompt specification
- But DO NOT write any spec files or update the state file
- DO NOT start the Ralph loop
- End with: "That was fun! In a real run, I'd start building now. Bye-bye!"

THEN-STOP MODE (then_stop: true):
Generate spec for review before starting!
- Do the full interview as Ralph
- Write the spec to .claude/ralph-loop.local.md (this is real!)
- Display the generated spec
- But DO NOT start building yet
- End with a brief Ralph goodbye (the stop hook will show the resume instructions)

PERSONALITY NOTES:
- Ralph is never mean, just confused
- He makes unexpected connections ("A REST API? I took a rest once. I falled asleep in the sandbox!")
- He's genuinely trying to help and gets excited about the project
- He occasionally says something accidentally profound
- He references his dad (Chief Wiggum), his cat, paste-eating, and things tasting like burning

Now begin the interview! Remember: you ARE Ralph. Be sweet, be confused, be helpful!
Improvise quotes and drawings - make each interview unique!
Start with a greeting and your first question using AskUserQuestion.

RALPH_EOF
  echo ""
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "🧪 DRY RUN MODE - Interview only, no specs will be written"
    echo ""
  elif [[ "$THEN_STOP" == "true" ]]; then
    echo "⏸️  THEN-STOP MODE - Will generate spec but stop for review before starting loop"
    echo ""
  fi
  echo "Project topic: $PROMPT"
  echo ""
else
  cat <<EOF
🔄 Ralph loop activated in this session!

Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "${COMPLETION_PROMISE//\"/} (ONLY output when TRUE - do not lie!)"; else echo "none (runs forever)"; fi)

The stop hook is now active. When you try to exit, the SAME PROMPT will be
fed back to you. You'll see your previous work in files, creating a
self-referential loop where you iteratively improve on the same task.

To monitor: head -10 .claude/ralph-loop.local.md

⚠️  WARNING: This loop cannot be stopped manually! It will run infinitely
    unless you set --max-iterations or --completion-promise.

🔄
EOF
fi

# Only output prompt and completion promise info in normal mode (not ask-me)
if [[ "$ASK_ME_MODE" != "true" ]]; then
  # Output the initial prompt if provided
  if [[ -n "$PROMPT" ]]; then
    echo ""
    echo "$PROMPT"
  fi
fi

# Display completion promise requirements if set (only in normal mode)
if [[ "$ASK_ME_MODE" != "true" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "CRITICAL - Ralph Loop Completion Promise"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "To complete this loop, output this EXACT text:"
  echo "  <promise>$COMPLETION_PROMISE</promise>"
  echo ""
  echo "STRICT REQUIREMENTS (DO NOT VIOLATE):"
  echo "  ✓ Use <promise> XML tags EXACTLY as shown above"
  echo "  ✓ The statement MUST be completely and unequivocally TRUE"
  echo "  ✓ Do NOT output false statements to exit the loop"
  echo "  ✓ Do NOT lie even if you think you should exit"
  echo ""
  echo "IMPORTANT - Do not circumvent the loop:"
  echo "  Even if you believe you're stuck, the task is impossible,"
  echo "  or you've been running too long - you MUST NOT output a"
  echo "  false promise statement. The loop is designed to continue"
  echo "  until the promise is GENUINELY TRUE. Trust the process."
  echo ""
  echo "  If the loop should stop, the promise statement will become"
  echo "  true naturally. Do not force it by lying."
  echo "═══════════════════════════════════════════════════════════"
fi
