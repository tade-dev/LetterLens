# Nano spike
1. Chrome 148+ on the Mac. Check chrome://on-device-internals shows the model as ready (or let the page download it). If the log says `downloadable` or `downloading`, leave the page open until the model finishes. If the Prompt API is present but `unavailable`, use Google Chrome.
2. `cp config.local.example.js config.local.js` and fill it from `~/.letterlens/`.
3. `python3 -m http.server 5173` in this folder, then open http://localhost:5173 (must be localhost for the debug token).
4. Click Run spike or Run card test and paste the report into LetterLens — Build. Run card test asks for the v1 card as JSON. Nothing is sent to the cloud.
