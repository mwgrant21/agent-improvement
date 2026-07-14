# Verification

### Inspect the artifact itself, not proxies

- When verifying assets or outputs (images, shipped files, build artifacts), open
  and look at the actual artifact and at what actually ships. Do not conclude from
  proxies like git history, MD5/hash comparisons, or folder names.
- Why: proxy reasoning sent a session in a circle comparing hashes of two web
  folders while the real answer was visible by opening the images and checking
  what the Android app actually bundled. The user's direct pointer to the real
  asset folder resolved it immediately.
- Evidence: 2026-07-13 session (tarot/TarotApp asset port) - agent self-reported
  "I'll open the pixels first next time" after a user correction.
- Added: 2026-07-13 (home-matt)
