---
name: conversation-log
description: Record prompts and responses from the current Claude Code session into a structured conversation log
disable-model-invocation: true
argument-hint: (no arguments)
---

# Conversation Log

Scan the current conversation and append a structured session log to the project's conversation log file. Each exchange is classified and formatted according to its type.

## Arguments

`$ARGUMENTS` is not used. This skill takes no arguments.

## Core Principles

1. **Never fabricate** — only log exchanges that actually occurred in the conversation
2. **Prompts are always recorded verbatim** — exactly as the user typed them
3. **Discussion responses are recorded in full** — preserve the substance and reasoning
4. **Task responses are summarised** — omit code blocks, file diffs, and step-by-step plan details. Keep the "what and why", drop the "how in detail"
5. **Append only** — never modify or delete existing log entries
6. **Use present-tense action verbs** for task summaries ("Created", "Fixed", "Added")

## Steps

### 1. Discover Project Context

Read the project's `CLAUDE.md` (it is auto-loaded into context). Extract:
- **Project Name** — from the `## Project Configuration` section
- **Repository** — from the `## Directory Paths` section

If these values cannot be found, report the error and stop.

### 2. Locate or Initialise Conversation Log

The conversation log lives at `{Repository}/Files/conversation-log.md`.

- If the `Files/` directory does not exist, create it
- If `conversation-log.md` does not exist, create it with the initialisation template (see below)
- If it exists, read it to find the last session entry

**Initialisation template** (only used for new files):
```markdown
# {Project Name} Project — Conversation Log

> Structured log of Claude Code session prompts and responses.
```

### 3. Handle Re-invocation

If the skill has already been invoked in this session (a session block for today with matching exchanges already exists at the end of the file), only append exchanges that occurred **after** the last logged entry. Do not duplicate entries.

### 4. Scan and Classify Exchanges

Scan the current conversation from the beginning (or from the last logged entry if re-invoked). For each user prompt and its response, classify the exchange as one of:

- **Discussion** — Q&A, explanation, decision-making, troubleshooting, research, conceptual questions
- **Task** — Plan mode, implementation, code generation, commits, file creation/editing, running commands, refactoring

**Classification guidelines:**
- If the response primarily involves reading/writing files, running commands, or generating code → **Task**
- If the response primarily involves explaining, discussing, or answering questions → **Discussion**
- If mixed, use the dominant activity. A question that triggers implementation is a **Task**
- Skill invocations (e.g. `/work-log`, `/version-bump`) are **Tasks**

### 5. Format Entries

Format each exchange based on its classification:

**Discussion:**
```markdown
### N. [Discussion]
**Prompt:** The exact text the user entered, verbatim.
**Response:** The full response text, preserving the substance of what was said. Include key reasoning, recommendations, and conclusions. May be lightly edited for readability (e.g. removing tool-call artifacts) but must preserve the meaning faithfully.
```

**Task:**
```markdown
### N. [Task]
**Prompt:** The exact text the user entered, verbatim.
**Summary:** Brief outcome-focused summary. What was done, what was created/modified/fixed, key decisions made. Omit code blocks, file diffs, generated code, and step-by-step implementation details — the artefact itself holds that detail.
```

### 6. Append Session Block

Append a new session block to the end of `conversation-log.md`:

```markdown

---

## YYYY-MM-DD HH:MM — Session

### 1. [Discussion]
**Prompt:** Why does the checkout fail on empty trolleys?
**Response:** The issue is in CheckoutService::validate(). It checks trolley item count but uses count() on the raw query result instead of the hydrated collection. When the trolley is empty, the query returns an empty array, and count() returns 0, but the comparison uses > instead of >=. The fix is to change the condition to strictly check for zero items before proceeding.

### 2. [Task]
**Prompt:** Fix the empty trolley validation bug in CheckoutService
**Summary:** Fixed CheckoutService::validate() to correctly reject empty trolleys. Changed the item count comparison from `> 0` to `>= 1` and added an early return with a user-facing error message. Modified 1 file.

### 3. [Task]
**Prompt:** /work-log include today
**Summary:** Ran work-log skill. Appended 1 new entry covering today's checkout validation fix.
```

**Format rules:**
- The session block starts with a `---` separator preceded by a blank line
- The heading uses `## YYYY-MM-DD HH:MM — Session` with the current date and time
- Exchanges are numbered sequentially: `### 1.`, `### 2.`, etc.
- Each exchange shows its type in square brackets: `[Discussion]` or `[Task]`
- Always end the file with a newline

### 7. Report Results

After appending, report:
- How many exchanges were logged
- Breakdown by type (e.g. "3 discussions, 2 tasks")
- Confirm the file path where the log was written

## Edge Cases

- **Very long discussions**: Preserve the substance but it is acceptable to condense extremely repetitive back-and-forth into the key points, noting that the discussion was extended
- **Failed tasks**: Still log them — note what was attempted and that it did not succeed
- **Skill invocations**: Log as Tasks. The prompt is the skill command, the summary describes what the skill did
- **Plan mode**: Log the initial prompt that entered plan mode as a single Task entry. Summarise the plan outcome, not every exploration step
- **System messages and tool artifacts**: Do not log system reminders, tool call details, or internal context — only log the user's prompt and the substantive response
- **Empty or trivial exchanges**: Skip greetings, acknowledgments, and exchanges with no substantive content (e.g. "ok", "thanks")

## Important Reminders

- Session headings use `## YYYY-MM-DD HH:MM — Session` — TWO hashes
- Exchange headings use `### N. [Type]` — THREE hashes
- Prompts are **always verbatim** — never paraphrase or clean up the user's words
- Discussion responses preserve substance — do not over-summarise into a single sentence
- Task summaries are outcome-focused — "Created X", "Fixed Y", "Added Z to W"
- Always end the file with a newline
- Do NOT modify any existing content in the conversation log — only append
