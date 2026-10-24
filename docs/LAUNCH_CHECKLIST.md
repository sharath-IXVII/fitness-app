# FittiePi launch: what you need to do

These steps need your accounts or decisions; nothing here can be done from code. Do them in this order. Each says how long it takes.

## 1. Decide the package name (2 minutes, can never change later)

The app's Android ID is still `com.fitalarm.fitalarm` from when it was called FitAlarm. Once you upload to Google Play it is permanent, and Firebase (step 2) needs it too.

Suggestion: `com.sharath.fittracker` (it has to be unique on Play, so a personal prefix is safest).

**Reply with the name you want, and I'll change it everywhere.**

## 2. Create the Firebase project (10–15 minutes, free)

Friends, challenges and real sign-in need this. It's free at your size (the Spark plan).

1. Go to https://console.firebase.google.com, then **Add project**. Name it "FittiePi". Google Analytics: off is fine.
2. Click the **Android** icon to add an app.
   - **Package name:** the one from step 1, exactly.
   - **App nickname:** FittiePi.
   - **SHA-1:** leave it empty for now; I'll get you the value (step 3).
3. Download **google-services.json** and send it to me. It is meant to ship inside the app; it isn't a password.
4. Left menu: **Build → Authentication → Get started.**
   - Enable **Google** (pick your email as the support email).
   - Enable **Phone.** Note: Google may ask you to upgrade to the pay-as-you-go plan for SMS codes. If it does, keep Phone off and launch with Google sign-in only. That is fully free.
5. Left menu: **Build → Firestore Database → Create database.** Choose a location near your users (for India: `asia-south1` Mumbai), and pick **production mode**. I'll give you the security rules to paste.

## 3. App signing key (10 minutes)

Today's test APK is signed with a throwaway key. Google Play needs your own permanent key, and Firebase needs its fingerprint (SHA-1) for Google sign-in.

**If you have a laptop with Java** (Android Studio includes it), run:

```bash
keytool -genkey -v -keystore fittracker-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then add it to GitHub so the build server can sign with it. Go to the repo → **Settings → Secrets and variables → Actions → New repository secret**, and add four secrets:

| Secret name | Value |
|---|---|
| `KEYSTORE_BASE64` | the file encoded: `base64 -w0 fittracker-upload.jks` (macOS: `base64 -i fittracker-upload.jks`) |
| `KEYSTORE_PASSWORD` | the store password you chose |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | the key password you chose |

**Back up the .jks file and both passwords somewhere safe** (for example Google Drive plus a password manager). If you lose them, you can't update the app.

If you don't have a laptop, tell me: I can create the key here and send you the file to keep.

## 4. Google Play Console: check this before promising a date

- A developer account costs US$25, one time: https://play.google.com/console
- **Important:** a *personal* account created after November 2023 must run a **closed test with at least 12 testers for 14 days in a row** before Google lets you publish to everyone. An *organisation* account (it needs a D-U-N-S number) skips this.
- So the realistic plan: in 1–2 days, start the **closed test** with your friends (12+ people, which also suits Friends and challenges). Public launch comes about 2 weeks later.
- Privacy policy: Play needs a public link. I can host `docs/PRIVACY.md` on GitHub Pages; you just need to tell me your contact email for it.

## What I'm building meanwhile

- Steps: GPS and the step sensor combined when location is allowed; step sensor only otherwise. Distance walked today.
- Workout and challenge reminders, alongside the existing My Day and water reminders.
- The Friends section with challenges ("I'm challenging you for the Winter Arc"), friend profiles with badges, and an XP leaderboard. It turns on as soon as I have your google-services.json.
- A full test pass of every feature, including the season switch on 1 January.
