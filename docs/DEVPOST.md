# Devpost submission — LetterLens

Draft for the #BuildHybridAI entry. Each heading matches a Devpost field. The numbers come
from the harness and the test suites, not from estimates; if the app changes before you
submit, check them again.

---

## Tagline

Official letters, explained. On your phone, not in a chatbot.

---

## Inspiration

A UK council tax letter is three pages of defined terms, a reference number, and one date
that actually matters. If English is your second language, or you have just arrived, or you
simply dread the post, the cost of misreading it is a penalty.

The obvious fix is to paste the letter into a chatbot. People do it, and they hate it,
because the letter has their address, their account number and their National Insurance
number in it. Scam letters make it worse: they are written to look exactly like the real
thing, and a chatbot will cheerfully tell you one looks fine.

LetterLens explains the letter without making you hand it over.

## What it does

Point the camera at a letter. In a few seconds you get a card:

- **What this is** — "A council tax reminder", the sender, the page count.
- **What they want you to do** — one or two plain sentences.
- **Deadline** — the date, the days left, and *the exact sentence from the letter it came
  from*. If the letter has no deadline, it says so. It never guesses one.
- **Watch out** — penalties and consequences, in plain words.
- **Scam signs** — if the letter has them, the card becomes a warning: every sign quoted
  from the letter, and how to check with the real sender. It will never tell you a letter
  is safe.
- **A badge saying where it was read** — green "Read on this iPhone", blue "Read in the
  cloud". The colour is never decorative. It only ever means where your letter went.

Ask for **Next steps** and it goes further: numbered actions and a script to read out on the
phone. That one needs the cloud, so it shows you exactly what will be sent first — the
letter with every personal detail replaced by a token, and a count: "11 details removed ·
0 photos sent". Your details are put back afterwards, on the phone.

History lives on the device. Nothing is uploaded without you pressing a button that says so.

## How we built it

**The hybrid part is the product, not a feature.** Reading a letter is routed on-device
first through Firebase AI Logic's `HybridModel`: Apple's Foundation Models on an iPhone that
has them, Gemini in the cloud when it does not. Planning is the other way round — cloud
primary, on-device as the offline fallback — because a plan is a longer piece of reasoning.
Availability is checked *before* the call, so the badge and the consent sheet are decided up
front and the SDK can never quietly fall back to the cloud without being asked.

**Redaction runs on the device, before anything leaves it.** `NSDataDetector` for phone
numbers, addresses and links; regex for UK postcodes, NI numbers, sort codes, account
numbers, card numbers, emails and references; line-anchored rules for the recipient block at
the head of a letter. Every hit becomes a token (`[NAME_1]`, `[ACCOUNT_1]`) held in a local
map, which is what lets the reply be refilled on the phone and what produces the honest
"details removed" count.

**The model is not trusted with the facts.** A validator checks every deadline against a
verbatim quote from the OCR text, and drops a date that has no quote behind it rather than
showing it. A separate guard rewrites any sentence that calls a letter safe or genuine,
because that is the one thing the app must never say.

- **iOS** — Swift 6, SwiftUI, iOS 26. VisionKit document camera, Vision OCR, SwiftData for
  local history, Firebase AI Logic, App Check, Remote Config for prompts and model names.
- **Web** — TypeScript and Vite, Gemini Nano through Chrome's Prompt API, the same card
  schema with the validator and redactor ported across. Live on Firebase Hosting.
- **Design** — a small system called Clear Ink: one ink navy, one green that only ever means
  on-device, one blue that only ever means cloud, amber only for deadlines, red only for
  warnings.

## Challenges we ran into

**Testing the pipeline is not testing the app.** A 15-letter harness was passing — type
15/15, deadlines 14/15, zero invented deadlines — while the scan-to-card flow in the app had
never once worked end to end. The harness called the service directly and never rendered a
view. Nearly every real bug was found afterwards, by tapping through the app on a real
letter.

**A consent sheet that dismissed itself.** The cloud-fallback sheet appeared and vanished
the instant a photo was picked. Three plausible diagnoses were wrong before tracing showed
it was the photo picker's own dismissal racing the sheet's presentation.

**The redactor had a name sitting there in plain text.** On the "what gets sent" screen the
salutation showed `[NAME_1]` while the address block two lines above still read
`Mr A Patel`. The rules only caught a name after "Dear". On a screen that promises your
details were removed, that is not a cosmetic bug.

**The safety guard could not see half the sentences it existed to catch.** It matched the
phrase `it's safe` with a straight apostrophe. Language models write `it's safe` with a
typographic one at least as often, and those sentences went through untouched.

**Hardware you cannot test on.** Apple Foundation Models need an A17 Pro or better; the
development iPhone is a 13, and the Simulator reports the model as available and then
guardrails every request. The on-device path is written against the documented API and the
routing is covered by tests, but it has not been run on eligible silicon, and the write-up
says so.

## Accomplishments that we're proud of

- The privacy claim is checkable rather than promised. The app shows the exact redacted text
  and a real count before anything is sent.
- Deadlines are quote-backed. Across 15 test letters the model invented zero dates — when it
  could not find one it said so, which is the harder behaviour to get.
- Both scam letters in the set were flagged with a quote, and no code path can call a letter
  safe.
- One card schema, one validator and one redactor shared in spirit across a Swift app and a
  TypeScript web app, with 163 and 44 tests behind them.

## What we learned

Routing between an on-device model and a cloud one is the easy half. The hard half is making
the *difference* legible to someone who never asked to care about it: a badge in two
colours, a count of what was removed, and a screen that shows the text before it goes.
Hybrid is a UI problem as much as an inference one.

We also learned to distrust a green test suite. The harness measured the model. It could not
see that the app was broken.

## What's next for LetterLens

- Explain the letter in another language, read on the device.
- PDF and photo input on the web build, which today takes pasted text.
- Accepting a letter shared from Mail or Files through the share sheet: built, not yet
  verified on a signed device build.

## Built with

Swift, SwiftUI, SwiftData, VisionKit, Vision, Apple Foundation Models, Firebase AI Logic,
Firebase App Check, Firebase Remote Config, Firebase Hosting, Gemini, Gemini Nano, Chrome
Prompt API, TypeScript, Vite.

## Try it out

- Web build: https://letterlens-ios.web.app
- Source: https://github.com/tade-dev/LetterLens (MIT)

---

## Still to fill in before submitting

- [ ] Demo video — the six-step story in the product doc
- [ ] Screenshots: home, letter card, scam warning, what gets sent, next steps
- [ ] Team members and roles
- [ ] Re-check the numbers above against the last harness run
