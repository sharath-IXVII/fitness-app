# FitAlarm backend

One Cloud Function for now: **`scanFood`**, which powers the food camera scanner.

The app sends a downscaled meal photo (≤1280 px JPEG) to this function. The function asks Claude (`claude-opus-5-5`, vision + structured outputs) for each visible item's portion, calories, protein, carbs, fat and fiber, then clamps the numbers to sensible ranges and returns JSON. The API key exists only as a Firebase secret. It is never in the app.

## What it enforces

- **Signed-in users only**, via Firebase Auth on a callable function.
- **25 scans per user per day.** The counter is kept in Firestore at `scanUsage/{uid}_{date}`, and client access to it is blocked by `firestore.rules`.
- **Image limits:** JPEG, PNG or WebP, base64, under about 3.7 MB.
- **Server-side refusal fallback** (`fallbacks: "default"`). If a safety classifier declines a photo, the API retries on a suitable model. If that also declines, the app shows a friendly message and offers manual entry.
- Photos are not stored by the function.

## Set up

Prerequisites: a Firebase project on the Blaze plan (Cloud Functions needs it), the Firebase CLI, Node 22, and an Anthropic API key from https://console.anthropic.com.

```bash
cd backend
firebase use --add                        # pick your Firebase project
firebase functions:secrets:set ANTHROPIC_API_KEY
cd functions && npm install && npm test   # compiles and runs unit tests
cd .. && firebase deploy --only functions,firestore:rules
```

The function deploys to `asia-south1` (Mumbai), which is the region the app calls. If you change one, change the other: `region` in `functions/src/index.ts` and `instanceFor(region:)` in `lib/features/scan/food_scanner.dart`.

The app turns the scanner on automatically once it is connected to Firebase (see "Firebase setup" in the root README). In demo builds the scan screen explains this and offers manual entry instead.

## Cost

One scan costs roughly 2–3K input tokens (image plus prompt) and a few hundred to a couple of thousand output tokens, including thinking. The daily limit caps spend per user. Adjust `DAILY_LIMIT` in `functions/src/index.ts`.

## Recommended before launch

- Turn on **App Check** (Play Integrity) and set `enforceAppCheck: true` so only your app can call the function.
- Set a budget alert on the Anthropic console.
