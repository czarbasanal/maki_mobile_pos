# Handoff: Waiting Dialog (contextual) — MAKI POS · cross-cutting

> ## ⛔ TWO HARD RULES — read `CLAUDE.md` in this bundle before you build
> 1. **Follow the mock faithfully.** Recreate the **Contextual** waiting dialog from
>    `MAKI POS Waiting Dialog.dc.html` pixel-for-pixel in Flutter — exact tokens, **both light and
>    dark**, primary-only color. Do not improvise, re-color, or substitute the spinner/label.
> 2. **Ask before wiring anything.** This spec is **appearance + usage only**. For *which* async calls
>    get wrapped, cancellation semantics, min-display timing hooks, and what shows on success/error,
>    **stop and ask the human** before implementing. Do not guess.

---

## What this is

A single **global blocking "busy" overlay** shown while a user-initiated async action is in flight —
saving, **billing out**, deleting, syncing, exporting, logging in. One centered card on the elevated
theme with a primary progress ring and a **verb-first label + one-line subtitle**.

The designer picked the **Contextual** variant as the standard. (`MAKI POS Waiting Dialog.dc.html` also
shows a label-only *Default* and a long-running *Cancelable* variant — treat those as the fallback and
the escalation, not the norm.)

This is a **design reference written in HTML** — a prototype of look + behavior. **Do not ship the HTML.**
Build it once as a reusable Flutter widget/helper (a `LoadingOverlay` / `showWaitingDialog(...)`) and
call it everywhere. Do not fork a per-screen spinner.

---

## ⭐ Global rule: waiting dialog sits ON TOP of skeleton loading

The app already has a **global skeleton-loading pattern** (`ListSkeleton` / shimmer placeholders). The
waiting dialog does **not** replace it — the two cover different moments and **compose**, with the dialog
layered above.

**Use SKELETON loaders (existing, unchanged) for passive reads — "the screen is loading its data":**
- First load of a list or detail screen.
- Tab / filter / date-range switches that refetch.
- Pull-to-refresh repaint.
- Anything where the page shape is known and can be shown as placeholders. Non-blocking, inline, the
  page owns it.

**Use the WAITING DIALOG (this component) for user-initiated writes/actions — "your action is being
processed":**
- Save / update job order · **Bill out** · Delete · Void · Approve · Sync · CSV export · Login.
- Anything the user tapped that must **block** until it resolves, where a partial UI would be wrong.

**How they layer:** the dialog is a modal on the top layer — if a skeleton is still resolving underneath
(e.g. a mutation fired right after navigation), the dialog covers it. **Never** show a full-screen
spinner where a skeleton belongs; **never** show a skeleton for a mutation. Decision rule in one line:

> **Loading _data_ → skeleton. Processing an _action_ → waiting dialog (on top).**

---

## Anatomy

Centered card over a dimming scrim.

- **Card** — radius **24**, padding `32px 34px`, min-width **220** / max-width **300**, column, centered.
- **Progress ring** — **56px**, **4px** stroke, indeterminate, **.8s linear** infinite. Track = faint
  primary; arc = primary. **This is the only color on the dialog** (neutral-by-default).
- **Title** — 20px below the ring, **17 / 600**, ink. **Verb-first, present tense**: `Billing out…`,
  `Saving…`, `Deleting…`, `Syncing sales…`. Generic `Please wait…` only when the action is ambiguous.
- **Subtitle** (contextual) — 6px below title, **13.5 / 1.5**, secondary, max-width ~212, centered.
  One short line of reassurance: "Loading this job order into the register."
- **Cancelable escalation only** — a full-width hairline divider then a centered **Cancel** (14.5 / 600,
  secondary). Omit for normal actions.

## Behavior — CONFIRM WIRING BEFORE IMPLEMENTING (Rule 2)

Recreate the visuals now; **ask the human** to confirm each of these before hooking up logic:

- **Blocks input**; the scrim is **not** tap-to-dismiss; the Android **back button is blocked**
  (`PopScope`) except in the cancelable variant.
- **Minimum display ~300ms** so it never flashes on fast calls; auto-close the instant the future
  resolves.
- **On result:** confirm what follows — a success toast/dialog, the error dialog (`ErrorStateView` /
  retry), or silent dismissal. Per action.
- **Cancelable variant:** only for genuinely long/background work (e.g. full sync); confirm cancellation
  actually aborts the operation, not just the dialog.
- **Which calls get wrapped:** confirm the exact list of actions/providers. Do not blanket-wrap reads —
  those stay skeletons.

## Design tokens

**Color — light / dark**
| Token | Light | Dark |
|---|---|---|
| Card surface | `#FFFFFF` | `#18262A` (+1px border `#243234`) |
| Scrim | `rgba(17,28,29,.32)` | `rgba(0,0,0,.6)` |
| Ring track | `rgba(40,62,70,.12)` | `rgba(232,184,76,.18)` |
| Ring arc (primary) | slate `#283E46` | gold `#E8B84C` |
| Title | `#16201F` | `#ECEFEF` |
| Subtitle | `#8A9296` | `#93A0A3` |
| Divider (cancelable) | `#ECECEC` | `#243234` |
| Cancel label | `#8A9296` | `#93A0A3` |

**Shadow** — Light `0 26px 60px -18px rgba(17,28,29,.42), 0 6px 16px rgba(17,28,29,.07)`; Dark
`0 26px 70px -18px rgba(0,0,0,.78)` (dark surface also carries the 1px `#243234` border).

**Geometry** — card radius **24** · padding `32px 34px` · ring **56 / 4px / .8s linear** · title
margin-top **20** · subtitle margin-top **6**.

**Type** — **Figtree**. Title 17/600 · subtitle 13.5/400 · Cancel 14.5/600.

## Suggested labels (verb-first)

| Action | Title | Subtitle |
|---|---|---|
| Save / update job order | `Saving…` | — |
| Bill out | `Billing out…` | Loading this job order into the register. |
| Delete | `Deleting…` | — |
| Void request / approve | `Submitting…` / `Approving…` | — |
| Sync (long) → cancelable | `Syncing sales…` | This can take a moment on a slow connection. |
| Export report | `Preparing export…` | — |
| Login | `Signing in…` | — |

## Maps to (Flutter)

- A reusable `LoadingOverlay` widget **or** `showDialog(context, barrierDismissible: false, …)` returning
  a handle you close when the future settles.
- `CircularProgressIndicator` with the **primary** color and a faint track.
- `PopScope(canPop: false)` to block back while busy (except cancelable).
- Wrap it in the existing async-call helper so every mutation goes through one path.

## Files in this bundle

- **`MAKI POS Waiting Dialog.dc.html`** — the design (Default · **Contextual** · Cancelable, light + dark).
  Open in a browser to view; the contextual variant is the target.
- **`support.js`** — runtime required by the `.dc.html`.
- **`CLAUDE.md`** — the two hard rules, verbatim.
