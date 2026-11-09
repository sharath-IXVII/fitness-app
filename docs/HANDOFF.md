# FittArc: handoff for a new Claude session

Read this first, then `docs/roadmap-next.md` (ideas for the next version) and `docs/store/listing.md` (store text and Play answers).

## What this is
FittArc ("The Rise of Arcs"), a Flutter fitness-game app for Android, sponsored by GetYr_io. The owner is not a developer: give clear, numbered steps, tell them what to do, and never ask for passwords or keys in chat (use GitHub secrets).
- Package: `com.GetYr_io.FittArc`. Name is always written **FittArc**.
- Repo (private): `sharath-IXVII/fitness-app`, branch `claude/phase-1-foundation`.
- Website repo (public): `sharath-IXVII/yrsite` (privacy.md, terms.md, delete-account.md, served at fittarc.in). Copy `docs/privacy.md`, `docs/terms.md`, `docs/delete-account.md` there when they change; regenerate the first two with `dart run tools/gen_policy_pages.dart`.
- Support email: support@fittarc.in.

## How to work on it
- Flutter 3.47 / Dart 3.13, Riverpod 3, go_router, SharedPreferences, Firebase Auth (Google only) + Cloud Firestore.
- Run `flutter analyze` and `flutter test` (about 264 tests) before every push. Format with `dart format -l 120` (NOT the default line width: that rewrites the whole codebase).
- Widget tests: lazy lists only build visible items, so scroll first (`scrollUntilVisible`, `ensureVisible`).
- Store screenshots are generated from the app: `tool/store_shots/render_test.dart` (needs `FLUTTER_SDK_FONTS` and `SHOTS_DIR` env vars, see the file).
- CI: `.github/workflows/build-apk.yml` runs analyze, tests, builds a signed APK and AAB, and publishes the APK to the (private) release tag `test-build`. The build number is `100 + run number`, so every Play upload has a higher version code. Signing secrets are GitHub secrets (KEYSTORE_*, KEY_*); never print them. A failing "Build APK" with "Failed to create parent directory" is a flaky runner: re-run it.
- From a cloud session, GitHub artifacts and `gh release download` are blocked. Use `gh api -H "Accept: application/octet-stream" repos/OWNER/REPO/releases/assets/ID` for the APK. The AAB must be downloaded by the owner from the Actions run page (artifact `fit-tracker-play-bundle`).

## Features built
Today page with arc calendar and streaks, seasonal Arcs and badges, XP and levels, workouts and 30-day challenges, My Day planner, alarms (workout alarm, strict mode, sleep mode, re-rings if the user stops, AM/PM wheel), steps (sensor + GPS), water, Diet (beta) with food camera, Food guide, Health page (camera heart rate estimate with a resting-pulse history, height/weight/BMI; the BP / sugar / oxygen log was removed on 2026-11-09 for Play), Watch page (live Bluetooth heart rate with zones and Arc minutes, Health Connect read-only for steps, heart rate, resting heart rate and sleep), Friends (codes, requests, challenges; XP only for finishing a challenge together), branded notifications with own sounds, cloud backup of progress, Food snaps (scan → story card, kept on the phone 30 days), Clubs (anyone creates/joins; text chat, 24 h, no links, report/block; the creator is the admin and sets GPS challenges (run/walk/cycle, distance, optional start point within 300 m, a start date and time (Start unlocks by itself, with a countdown) and how long it stays open: 1 h to 30 days); members run them with GPS (foreground location service), finishes are checked for believable speed in the app and in rules, ranking by time in the club, XP 50 + 10/km once per challenge, kept on the phone; `lib/features/clubs`).

## State of the Play Store (as of 2026-11-09)
- App created on a **personal** developer account. Listing, graphics, screenshots (phone / 7-inch / 10-inch), Data safety (CSV import), content rating, target audience (18+), ads, app access (needs a Google test login), Health Connect permission texts, full-screen intent (Alarm clock) all filled in.
- Internal / closed testing: a release was uploaded; the closed test has not started its 14 days with 12 testers.
- **Medical flag fixed in code (2026-11-09):** the BP / sugar / oxygen log, the 7-day BP card and the doctor report were removed, so the app has no Medical feature. Owner still has to: upload the new AAB, untick the Medical box in the Health apps declaration, update Data safety (no BP/sugar/oxygen) and copy `docs/privacy.md` to `yrsite`.
- Clubs setup (owner, once): publish `firestore.rules`, and in Firebase console → Firestore → TTL policies add a policy on collection group `messages`, field `expireAt`, so old club messages are deleted from the server.
- Festivals (`lib/features/festivals`): Diwali, Holi, Eid, Ganesh Chaturthi, Dussehra (dates built in to 2032), New Year, Sankranti, Republic Day, Independence Day, Christmas (every year). A greeting card on Today and a light sparkle on every page, on and off by date. To fix a date or add a festival without an update: Firestore → collection `config` → document `festivals` → field `dates` (array of maps `{id: "diwali", day: "2033-10-22", before: 2, after: 2}`) and optional `custom` (array of maps `{id, name, greeting, line, emoji, colors: ["#F2C14E", "#1E7B4F"]}`).
- Still to do on Play: add Play's app-signing SHA-1/SHA-256 to Firebase (project `fittiepi`, owner Gmail aravindra915@gmail.com) so Google sign-in works on Play installs; publish `firestore.rules` in Firebase (friend codes and requests need it); 12+ testers for 14 days; then apply for production.

## Things never to do
- Never claim the phone measures blood pressure, sugar or oxygen. Heart rate from the camera is a labelled estimate. No medical claims or health-risk predictions.
- Don't change names or logos without the owner's decision. Keep the private repo private; only website files go to `yrsite`.
- Don't put keys or passwords in chat, code or docs.
