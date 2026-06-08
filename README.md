# Calendar QuickAdd

A client-only web tool that turns plain text like `dentist tuesday 3pm` into a Google
Calendar event, with a 15-minute reminder, optional recurrence, and a global `Alt+C`
hotkey to launch it. No backend, no build step, one HTML file.

> Type a sentence, hit Enter, and the event is on your calendar.

## What it does

- Parses natural language into a structured event (`title`, `start`, `end`, `recurrence`).
- Leftover text after the date becomes the event title (`lunch with sam friday 1pm` to
  `Lunch With Sam`).
- Sets duration from phrases like `for 90m`, `for 2 hours`, `for an hour`, `for 1.5h`,
  or `for half an hour`. Natural ranges such as `12-1pm` or `3 to 5pm` set the end time
  directly.
- Detects recurrence keywords and converts them to an RRULE
  (for example `RRULE:FREQ=WEEKLY;BYDAY=MO`).
- Adds a 15-minute popup reminder to every event.
- Applies article-aware title case, capitalizing each word except small words like
  `the`, `a`, `an`, `is`, `for`, `of`, `to`, and always capitalizing the first word.
- Shows a live preview as you type and a "view in calendar" link on success.

## How it works

The whole app is a single static page served over `http://localhost:8000`. There is no
server-side code.

- **Parsing.** [`chrono-node`](https://github.com/wanasit/chrono) v2 ships no plain
  `<script>` browser bundle, so it is loaded as an ES module from `https://esm.run`,
  exposed as `window.chrono`, and a `chrono-ready` event guards the first parse until the
  parser is available.
- **Auth.** Google Identity Services (GIS) token client, popup flow. The implicit redirect
  flow is deprecated by Google and auth-code with PKCE needs a backend, so the GIS popup is
  the only viable no-backend method. The token is cached in `localStorage` and restored on
  load. On page load the app only restores from the cached token and never triggers a token
  request on its own, which avoids the browser blocking a popup that has no user gesture
  behind it. The interactive popup opens exactly once, straight from the click.
- **Calendar write.** A single `events.insert` call carries `summary`, `start`/`end`,
  optional `recurrence`, and `reminders.overrides: [{ method: "popup", minutes: 15 }]`.
- **Scope.** The app requests only `https://www.googleapis.com/auth/calendar.events`, so a
  leaked token can touch calendar events and nothing else.

## Engineering notes

A few problems that were worth solving and are baked into the current version:

- **chrono v2 has no script bundle.** The pinned CDN path 404'd and `chrono` was never
  defined, so nothing parsed. Fixed by loading it as an ES module and gating the first
  preview on a readiness event.
- **Firefox blocked the sign-in popup.** A silent token refresh on load opened a popup with
  no user activation, which Firefox blocked. The fix was to never auto-request a token on
  load and to open a single interactive popup from inside the click handler.
- **Two popups on the add path.** An early version opened a silent popup and then an
  interactive one in a `.catch`, so the second opened outside the live user gesture. Now the
  add path awaits a single `ensureToken(true)` and opens one popup.
- **Privacy add-ons break the token handoff.** With strict tracking protection or certain
  privacy extensions, Firefox storage partitioning starves the GIS token handoff. The cure
  is a `localhost` exception for the extension rather than disabling it.

## Setup

1. Create a project in the Google Cloud Console and enable the **Google Calendar API**.
2. Configure the OAuth consent screen: audience **External**, publishing status **Testing**,
   and add your own Google account as a **test user**.
3. Create an **OAuth client ID** of type **Web application** with the authorized JavaScript
   origin set to exactly `http://localhost:8000`.
4. Paste your client ID into `index.html`. The web OAuth client ID is sent to the browser
   anyway and is not a secret, but use your own and do not commit anyone else's.

Then serve the folder and open it:

```bash
python -m http.server 8000
```

Open `http://localhost:8000` (use `localhost`, not `127.0.0.1`, since only the former is a
registered origin), sign in once, and start typing.

## Global Alt+C launcher (Windows)

`calendar-quickadd.ahk` is an AutoHotkey v2 script that binds a system-wide `Alt+C`. When
pressed it:

1. Probes `http://localhost:8000`. If nothing is listening, it starts
   `python -m http.server 8000` hidden, using the script's own folder as the working
   directory, and waits up to about five seconds for the server to come up.
2. Focuses an existing Calendar QuickAdd tab if one is open, otherwise opens it in the
   browser.

Keep the `.ahk` file next to `index.html`. The hidden server persists until logout or
reboot. To re-arm the hotkey after a reboot, add a shortcut to the script in the Windows
Startup folder.

## Files

```
index.html               The full app: parsing, auth, calendar write, UI
calendar-quickadd.ahk     Global Alt+C launcher that also starts the local server
```

## Limitations

- The OAuth client runs in testing mode, so it shows Google's unverified-app screen on first
  sign-in and the token behaves like a roughly one-hour session with silent refresh.
- The global hotkey launcher is Windows and AutoHotkey specific. The in-page `Alt+C` works
  in any browser but only when the tab is focused.

## Tech

Vanilla HTML, CSS, and JavaScript. `chrono-node` for date parsing. Google Identity Services
and the Google Calendar API. AutoHotkey v2 for the launcher. No framework, no bundler.
