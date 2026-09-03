# Date Range Calendar — Implementation Guide

Reference implementation: `DateRangeCalendar.dc.html`
Skin and tokens: `Dashboard - Spec.md`. Read that first; this component uses its §2 tokens.

A shared `DateRangeFilter` for the whole admin — it belongs in `FilterBar` (spec §7) and is
used by Receiving, Job Orders, Reports, Expenses and Activity Logs.

---

## 1. What this replaces

The first pass rendered two native `<input type="date">` fields side by side inside a white
pill: `mm/dd/yyyy 🗓 — mm/dd/yyyy 🗓`. Three problems.

1. **Two calendars for one range.** Picking a range meant opening one date picker, closing
   it, opening a second, and holding the first date in your head — with no visual connection
   between them.
2. **Native pickers can't be styled.** Both the field chrome and the popup are browser UI, so
   the control looked foreign in both light and dark and ignored every token.
3. **`mm/dd/yyyy` is a format demand, not a prompt.** It invites typing, and typing invites
   invalid input, backwards ranges and locale confusion.

Now: one calendar. First click sets From, second sets To.

---

## 2. Interaction

**Two clicks, one calendar.**

| State | Click behavior |
|---|---|
| Nothing selected | sets **From**, clears To |
| From set, To empty | sets **To** |
| From set, clicked day is *before* From | swaps — clicked day becomes From, old From becomes To |
| Both set | starts over: clicked day becomes From, To clears |

That third row matters. A user who clicks the end of their range first should not get an
error or an empty result — reversing the pair is what they meant. Never validate
"To must be after From"; make it impossible to express.

**Hover preview.** While From is set and To is empty, hovering a day paints the provisional
range so the user sees the span before committing. Hover does nothing in the other two
states — a live preview after the range is set would read as an accidental change.

**Header echoes state.** A two-up `From` / `To` block sits above the grid, values in mono,
placeholder `Pick a date` in `--text-3`. The footer hint changes with state: *Click a day to
start* → *Click a second day to end* → *Range set*. Together these mean the user never has to
infer which click they are on.

**Apply is explicit.** Selecting dates does not filter; `Apply` does. It sits at `opacity
.45` until both dates exist. This is deliberate for a table filter — refetching on the first
click would fire a query for a range the user hasn't finished describing. (For a
low-cost/local filter, applying on the second click and closing is also fine — pick one and
be consistent across screens.)

**Dismissal**, same contract as every dropdown in this app: close on `Apply`, on re-clicking
the `Custom` pill, on `mousedown` outside the wrapper, and on `Escape` — with both document
listeners registered in `componentDidMount` (capture phase) and **removed in
`componentWillUnmount`**.

---

## 3. Anatomy

The `Custom` pill lives in the existing preset segmented control; the calendar is a popover
anchored to it. Presets and custom are one control, not two.

```
wrapper (position:relative, ref for outside-click)
├ segmented control — Today · 7 days · 30 days · Custom
└ popover (absolute, top: calc(100% + 8px), z-index: 50, width: 296px)
   ├ From / To summary   (--surface-2 inset, radius 10px)
   ├ month nav           (chevron · Month YYYY · chevron)
   ├ 7-col grid          (day-of-week labels + 42 day cells)
   └ footer              (hint · Reset · Apply)
```

Popover: `--surface`, `1px --border`, radius 14px, padding 14px, `gap: 12px`,
`box-shadow: 0 20px 48px -16px rgba(0,0,0,.32)`.

**Always render 42 cells** — six weeks, with leading and trailing days from the neighboring
months in `--text-3`. A grid that changes height between months makes the footer jump under
the cursor.

Day cell: 32px tall, 12px mono, `gap: 2px` between cells.

| Cell state | Background | Text | Radius |
|---|---|---|---|
| Default (in month) | transparent | `--text-2` | 8px |
| Adjacent month | transparent | `--text-3` | 8px |
| Today | transparent | `--accent-text` 600 | 8px |
| In range | `--accent-soft` | `--accent-text` 500 | **0** |
| Range endpoint | `--accent` | `--accent-ink` 600 | `8px 0 0 8px` / `0 8px 8px 0` |
| Single day selected | `--accent` | `--accent-ink` 600 | 8px |

The radius rule is what makes the range read as one continuous bar: interior days square off,
and each endpoint keeps the radius only on its outer side. Endpoints of a one-day range keep
all four corners.

Adjacent-month cells are display-only — `cursor: default`, no handlers. To move months, use
the chevrons.

Day-of-week labels: 9.5px uppercase `--text-3` 600, `S M T W T F S`. Week starts Sunday;
change to Monday if the client prefers, but change it in one place.

---

## 4. Implementation notes

**Keys, not `Date` objects.** Every cell carries a `YYYY-MM-DD` string. Comparisons
(`key > lo && key < hi`) are plain lexicographic string compares — correct for this format,
and they avoid the timezone and DST bugs that come from comparing `Date` instances. Parse to
a `Date` only to format for display.

**Never send a `Date` to the server.** Send the two `YYYY-MM-DD` strings and let the API
interpret them in the shop's timezone (`Asia/Manila`). A client-side `toISOString()` shifts
the date across midnight for anyone west of UTC and silently drops or adds a day of results.

**Range semantics:** `from` is inclusive at 00:00:00, `to` is inclusive through 23:59:59.
State it in the API contract — an exclusive `to` is the classic off-by-one that hides the
newest day's records.

**"Today" must come from the server's business date**, not `new Date()` on the client. A
shift that runs past midnight still reports the opening day. The reference hard-codes
`2026-09-03` as fixture data.

**Selection state is three fields:** `from`, `to`, `hover` — all nullable keys. Anything more
(a "which click am I on" flag, a mode enum) is derivable and will drift out of sync.

---

## 5. Component contract

```ts
<DateRangeFilter
  presets={['Today','7 days','30 days']}   // 'Custom' appended automatically
  value={{ preset: string } | { from: string, to: string }}
  onChange={(value) => void}          // fires on preset click, or on Apply
  weekStartsOn={0}                    // 0 = Sunday
  today={string}                      // server business date, YYYY-MM-DD
  maxDate={string?}                   // usually today — no future ranges on a sales report
  minDate={string?}
/>
```

`maxDate` should default to today on every historical screen. Disabled days render like
adjacent-month cells (`--text-3`, `cursor: default`, no handlers).

**When the range is applied**, the `Custom` pill should show the applied span rather than the
word "Custom" — e.g. `Sep 1 – Sep 3` — so the active filter is legible without reopening the
popover. Not built in the reference; add it when wiring.

---

## 6. Not built

Typed entry as an alternative to clicking (worth adding for long-ago ranges: a small text
field that parses and jumps the calendar, never the only input) · relative presets inside the
popover (This month, Last month, This year) · two-month side-by-side view for long ranges ·
keyboard grid navigation (arrows to move, `Enter` to select) · `maxDate` / `minDate`
enforcement.

Keyboard navigation is the significant omission. Until it exists the control is mouse-only,
which fails the app's own definition of done.

---

## 7. Definition of done

- Tokens only; no literal hex, px font size, radius or shadow outside the token sheet.
- Light and dark both checked by eye.
- Reversed selection swaps rather than erroring; both-set click starts a new range.
- Hover preview only while From is set and To is empty.
- Closes on Apply, outside `mousedown` and `Escape`; both listeners removed on unmount.
- 42 cells always rendered; grid height constant across months.
- Dates cross the wire as `YYYY-MM-DD` strings; `to` is inclusive.
- Arrow-key grid navigation with `Enter` to select, and a visible focus ring.
