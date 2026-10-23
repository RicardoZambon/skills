# Writing rules (zambon plugin)

Apply these to every text a person will read: chat replies, docs, ADRs, PR and MR descriptions, tickets, review notes and commit messages.

- **Say only what is needed.** Cut filler, repetition and side facts. Don't be sloppy either: complete thoughts, correct terms.
- **Short, simple sentences.** One idea per sentence. Split long or nested ones, because readers skim.
- **No section-number citations like `§3.2`.** Explain the idea in a few words instead. Cite a section only when the idea is too complex to explain briefly.
- **No code locations in the body.** File paths and line numbers are hard to read and go stale. When one is truly needed later, put it in a **References** section at the end.
- **No bare commit IDs.** A hash means nothing on its own. Say what the commit did. If the hash is still needed, put it in References.
- **Link every ticket, issue, PR, MR and ADR** with its full URL, so the reader can open it in one click.

Before sending a text, re-read it against this list. For a longer text, the `writing-style` skill has examples and a checker script.
