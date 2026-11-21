# Nano spike

Card tests use LetterLens card schema v2. `type` and `sender_kind` must be exact lowercase members of the lists below. The model should answer `not_sure` when it is unsure. A value that is not on the list fails validation. `firebase/remoteconfig.template.json` still holds the v1 prompt and is not changed here.

sender_kind, from the handover's docs/PROMPTS.md `sender_kind` plus `not_sure`: council, hmrc, bank, benefits, school, utility, landlord, nhs, other, not_sure

type, agreed in the team room and approved by Tade on 13 Nov 2026, because the handover docs do not define a type list: bill, reminder, final_notice, change_notice, information_request, consent_request, refund, information, appointment, penalty, other, not_sure

1. Chrome 148+ on the Mac. Check chrome://on-device-internals shows the model as ready (or let the page download it). If the log says `downloadable` or `downloading`, leave the page open until the model finishes. If the Prompt API is present but `unavailable`, use Google Chrome.
2. `cp config.local.example.js config.local.js` and fill it from `~/.letterlens/`.
3. `python3 -m http.server 5173` in this folder, then open http://localhost:5173 (must be localhost for the debug token).
4. Click Run spike, Run card test, or Run card test (Chrome JSON mode) and paste the report into LetterLens — Build. Run card test asks for the v2 card as JSON through Firebase AI Logic. Chrome JSON mode is a comparison only: the same prompt, with `type` and `sender_kind` as JSON Schema enums. Nothing is sent to the cloud.
