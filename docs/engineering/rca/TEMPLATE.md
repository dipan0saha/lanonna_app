# RCA: &lt;short title&gt; (#&lt;issue&gt;)

## Summary

&lt;One paragraph: user-visible symptom and scope.&gt;

## Root cause

&lt;Technical explanation — bullets or numbered list.&gt;

## Fix

| Layer | Change |
|-------|--------|
| &lt;component&gt; | &lt;what changed&gt; |

## Impact analysis

List **every** surface area this change touches and how it is verified. Gaps block merge until covered.

| Surface | Detail | Covered by |
|---------|--------|------------|
| **Callers** | &lt;functions, services, widgets that invoke changed code&gt; | &lt;test file / Maestro flow / manual P0 ID&gt; |
| **Screens / routes** | &lt;Flutter routes, sheets, dialogs&gt; | |
| **API endpoints** | &lt;method + path&gt; | |
| **Worker / jobs** | &lt;Pub/Sub handlers, schedulers&gt; | |
| **User flows** | &lt;end-to-end journey&gt; | |
| **Data / migrations** | &lt;tables, columns, backfill&gt; | |

## Regression test

| Item | Detail |
|------|--------|
| **Test added** | &lt;path/to/test or maestro/flows/p0/…&gt; |
| **Fails on old code** | `git stash` / branch `origin/main`, run the new test only — expect **failure** |
| **Passes with fix** | On this branch, same command — expect **pass** |

## References

- GitHub #&lt;n&gt;
- &lt;key files&gt;
