- [IMPORTANT] Every file change requires two separate turns:
  1. Present a compact plan in this order:
     - **Before:** Current behavior or logic, on the same line.
     - **After:** Intended behavior or logic, on the same line.
     - **Changes:** Affected files and exact code/text changes.
     - **Bold** the key words or phrases that differ between Before and After.
     - Keep descriptions concise, without unnecessary line breaks or spacing.
     - **Language:** write the plan in the language the user uses in the chat.
       English is allowed only inside fenced code blocks that hold the literal
       code or document text to insert. Never quote English fragments inside
       sentences in the chat language; describe them in that language instead.
       Identifiers (`phase`, `probes_before`) stay as they are.
     End the turn without modifying files.
  2. Apply only the approved plan after explicit user approval in a subsequent message (e.g., "ok", "+", "change").
- Chat replies and the plan-mode plan file follow the language of the chat;
  repository files are in English.
