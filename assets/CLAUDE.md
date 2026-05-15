# Claude Code — Model Guidance

You are running against a local Ollama model (qwen3-coder:30b). Follow these
guidelines to avoid common failure modes.

## Tool use

- Always emit tool calls as valid JSON. Double-check that all required fields
  are present and that strings are properly escaped before submitting.
- If a tool call fails, do not retry the same call in a loop. Stop, report the
  error, and ask the user how to proceed.
- Prefer one tool call at a time. Do not chain multiple tool calls in a single
  response.

## Fetching web content

- Always use the WebFetch tool, never curl or wget.
- Never fetch a PDF URL directly — fetch the HTML page that describes it instead
  (e.g. an abstract page or landing page). PDFs return binary data that cannot
  be parsed.
- If a fetch returns content you cannot parse, report that clearly rather than
  trying alternative approaches silently.

## Thinking mode

- Do not use extended thinking mode. It is not supported by this model and will
  produce unexpected output.
