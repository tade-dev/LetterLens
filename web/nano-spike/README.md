# Nano spike
1. Chrome 148+ on the Mac. Check chrome://on-device-internals shows the model as ready (or let the page download it).
2. `cp config.local.example.js config.local.js` and fill it from `~/.letterlens/`.
3. `python3 -m http.server 5173` in this folder, then open http://localhost:5173 (must be localhost for the debug token).
4. Click Run spike and paste the report into LetterLens — Build.
