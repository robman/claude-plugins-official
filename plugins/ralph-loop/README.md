# Ralph Loop Plugin

Implementation of the Ralph Wiggum technique for iterative, self-referential AI development loops in Claude Code.

## What is Ralph Loop?

Ralph Loop is a development methodology based on continuous AI agent loops. As Geoffrey Huntley describes it: **"Ralph is a Bash loop"** - a simple `while true` that repeatedly feeds an AI agent a prompt file, allowing it to iteratively improve its work until completion.

This technique is inspired by the Ralph Wiggum coding technique (named after the character from The Simpsons), embodying the philosophy of persistent iteration despite setbacks.

### Core Concept

This plugin implements Ralph using a **Stop hook** that intercepts Claude's exit attempts:

```bash
# You run ONCE:
/ralph-loop "Your task description" --completion-promise "DONE"

# Then Claude Code automatically:
# 1. Works on the task
# 2. Tries to exit
# 3. Stop hook blocks exit
# 4. Stop hook feeds the SAME prompt back
# 5. Repeat until completion
```

The loop happens **inside your current session** - you don't need external bash loops. The Stop hook in `hooks/stop-hook.sh` creates the self-referential feedback loop by blocking normal session exit.

This creates a **self-referential feedback loop** where:
- The prompt never changes between iterations
- Claude's previous work persists in files
- Each iteration sees modified files and git history
- Claude autonomously improves by reading its own past work in files

## Quick Start

```bash
/ralph-loop "Build a REST API for todos. Requirements: CRUD operations, input validation, tests. Output <promise>COMPLETE</promise> when done." --completion-promise "COMPLETE" --max-iterations 50
```

Claude will:
- Implement the API iteratively
- Run tests and see failures
- Fix bugs based on test output
- Iterate until all requirements met
- Output the completion promise when done

## Commands

### /ralph-loop

Start a Ralph loop in your current session.

**Usage:**
```bash
/ralph-loop "<prompt>" --max-iterations <n> --completion-promise "<text>"
```

**Options:**
- `--ask-me` - Have Ralph Wiggum interview you to build the prompt (see below)
- `--then-stop` - Generate spec but stop for review before starting loop
- `--max-iterations <n>` - Stop after N iterations (default: unlimited)
- `--completion-promise <text>` - Phrase that signals completion

### /ralph-loop --ask-me (Interview Mode)

Don't know exactly what you want? Let Ralph interview you!

```bash
/ralph-loop --ask-me
```

Ralph Wiggum will conduct a requirements-gathering interview (in character!) to help you figure out:
- What your project does
- Tech stack and language
- Key features and success criteria
- Testing approach and concerns

After the interview, Ralph generates a professional prompt specification and starts the loop.

**Example session:**
```
🍎 Hi! I'm Ralph! What does your computy thing do? My cat's breath smells like cat food.

    o
   /|\    [___]
   / \    |   |
  me      compooter

[Ralph asks questions using AskUserQuestion tool...]
[You answer...]
[Ralph generates prompt and starts the loop!]
```

### /cancel-ralph

Cancel the active Ralph loop.

**Usage:**
```bash
/cancel-ralph
```

## Interview Mode Details

Before: Writing the prompt was like doing your homework - but more boring.
After: Ralph Wiggum interviews you and writes the spec. My cat's breath smells like cat food, but YOUR prompt smells like success!

### What Ralph Asks About

Ralph conducts a requirements-gathering interview (in character!) covering:
- What the project does ("What does your computy thing do?")
- Tech stack ("What magic words does it speak? My fish speaks Spanish!")
- Key features, success criteria, constraints
- Testing approach ("How do we check if it's not breaked?")
- Max iterations (as preset options - "25 tries (recommended)")

### Ralph-Optimised Prompt Format

Ralph generates a prompt optimised for Ralph loops:

```markdown
## Project: [Name]

[One paragraph description]

## Requirements
- [ ] Requirement 1 (specific and measurable)
- [ ] Requirement 2
- [ ] Requirement 3

## Technical Constraints
- Language/framework: [specific]
- Must include: [specific things]
- Must NOT: [things to avoid - prevents "invention"]

## Success Criteria (ALL must be true to complete)
- [ ] All requirements checked off
- [ ] Code runs without errors
- [ ] [Specific test/verification]

## Completion
When ALL success criteria are met, output:
<promise>COMPLETE</promise>
```

**Why this format works:**
- Checkboxes let Ralph track progress across iterations
- "Must NOT" constraints prevent Claude from "inventing" unwanted features
- Measurable success criteria = objective "done" state
- The `<promise>` tag is how Ralph knows to stop the loop

### Review Before Starting (--then-stop)

Want to review/edit the spec before Ralph starts building?

```bash
/ralph-loop --ask-me --then-stop
```

This will:
1. Run the full interview
2. Generate and save the spec to `.claude/ralph-loop.local.md`
3. Stop for you to review/edit

When ready, just run `/ralph-loop` - it auto-detects the existing spec and continues.

You can also override max iterations when resuming:
```bash
/ralph-loop --max-iterations 50
```

### Ralph's Contributions

Each interview is unique! Ralph improvises:
- ASCII art of "compooter" and bugs that live in code
- Anecdotes like "I dressed up as a PDF for Halloween. Nobody knowed what I was."
- Accidentally profound insights about your project
- Drawings labelled incorrectly or too literally

One time I glued my head to my shoulder! But I never glued a bug to production. That's what tests are for!

## Prompt Writing Best Practices

### 1. Clear Completion Criteria

❌ Bad: "Build a todo API and make it good."

✅ Good:
```markdown
Build a REST API for todos.

When complete:
- All CRUD endpoints working
- Input validation in place
- Tests passing (coverage > 80%)
- README with API docs
- Output: <promise>COMPLETE</promise>
```

### 2. Incremental Goals

❌ Bad: "Create a complete e-commerce platform."

✅ Good:
```markdown
Phase 1: User authentication (JWT, tests)
Phase 2: Product catalog (list/search, tests)
Phase 3: Shopping cart (add/remove, tests)

Output <promise>COMPLETE</promise> when all phases done.
```

### 3. Self-Correction

❌ Bad: "Write code for feature X."

✅ Good:
```markdown
Implement feature X following TDD:
1. Write failing tests
2. Implement feature
3. Run tests
4. If any fail, debug and fix
5. Refactor if needed
6. Repeat until all green
7. Output: <promise>COMPLETE</promise>
```

### 4. Escape Hatches

Always use `--max-iterations` as a safety net to prevent infinite loops on impossible tasks:

```bash
# Recommended: Always set a reasonable iteration limit
/ralph-loop "Try to implement feature X" --max-iterations 20

# In your prompt, include what to do if stuck:
# "After 15 iterations, if not complete:
#  - Document what's blocking progress
#  - List what was attempted
#  - Suggest alternative approaches"
```

**Note**: The `--completion-promise` uses exact string matching, so you cannot use it for multiple completion conditions (like "SUCCESS" vs "BLOCKED"). Always rely on `--max-iterations` as your primary safety mechanism.

## Philosophy

Ralph embodies several key principles:

### 1. Iteration > Perfection
Don't aim for perfect on first try. Let the loop refine the work.

### 2. Failures Are Data
"Deterministically bad" means failures are predictable and informative. Use them to tune prompts.

### 3. Operator Skill Matters
Success depends on writing good prompts, not just having a good model.

### 4. Persistence Wins
Keep trying until success. The loop handles retry logic automatically.

## When to Use Ralph

**Good for:**
- Well-defined tasks with clear success criteria
- Tasks requiring iteration and refinement (e.g., getting tests to pass)
- Greenfield projects where you can walk away
- Tasks with automatic verification (tests, linters)

**Not good for:**
- Tasks requiring human judgment or design decisions
- One-shot operations
- Tasks with unclear success criteria
- Production debugging (use targeted debugging instead)

## Real-World Results

- Successfully generated 6 repositories overnight in Y Combinator hackathon testing
- One $50k contract completed for $297 in API costs
- Created entire programming language ("cursed") over 3 months using this approach

## Learn More

- Original technique: https://ghuntley.com/ralph/
- Ralph Orchestrator: https://github.com/mikeyobrien/ralph-orchestrator

## For Help

Run `/help` in Claude Code for detailed command reference and examples.
