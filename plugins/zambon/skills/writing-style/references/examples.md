# Before and after

Each pair shows the same content. The "after" version is what the rules ask for.

## PR description

**Before**

> This PR implements the changes discussed in §4.2 of the design doc, which required refactoring `src/Billing/InvoiceCalculator.cs:212` to move the rounding logic, previously introduced in 9f3c2ab and partly reverted in 4e71d0c, into a dedicated helper so that the tax engine and the export job (see PROJ-881) can share it without duplicating the edge cases around half-cent values.

**After**

> Invoices and the export job now round amounts the same way. Both use one shared rounding helper, so half-cent values no longer differ between the two.
>
> **Why:** the export job had its own copy of the rounding code, and the copies had drifted apart ([PROJ-881](https://example.atlassian.net/browse/PROJ-881)).
>
> **How to check:** export an invoice with a half-cent line. The total in the file now matches the screen.
>
> ## References
>
> - Rounding helper: `src/Billing/Rounding.cs`
> - Earlier attempt, partly reverted: `9f3c2ab`

## Review comment

**Before**

> I think there might potentially be an issue here, since as per the guidelines (§2) we generally try to avoid this pattern, and it could maybe cause problems later on in some scenarios.

**After**

> This loop runs a database query for every row, so a 500-row import makes 500 round trips. Load the rows in one query before the loop.

## Chat reply

**Before**

> Great question! I took a look at the configuration and after investigating several files it appears that the most likely cause of the problem you are seeing is that the timeout value, which is currently set in `config/app.yml:14`, is lower than the time the job actually needs to complete.

**After**

> The job times out because its limit is 30 seconds and the job needs about 45. Raising the limit to 60 seconds fixes it. Want me to change it?

## Commit message

**Before**

> fix: revert part of a1b2c3d and adjust per review

**After**

> fix(export): round half-cent values the same way as invoices
>
> The export job had its own rounding code, which drifted from the
> invoice code and produced totals one cent off.
