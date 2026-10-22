# Releasing Fit Tracker on Google Play

This is a checklist for the first Play Store release. Items marked **(you)** need your accounts or decisions.

## 1. Before the first build

- **(you) Name and package.** Pick the final app name, then set `applicationId` and `namespace` in `android/app/build.gradle.kts` (for example `com.yourname.fitalarm`). The package name can't change after the first upload. Update the Firebase Android app to match.
- **(you) Contact email.** Replace `[your contact email]` in `lib/features/profile/privacy_policy.dart`, then regenerate or edit `docs/PRIVACY.md` to match.
- **(you) Firebase.** Connect Firebase (root README, "Sign-in"), add your **release** SHA-1 and SHA-256 fingerprints to the Firebase Android app (Google sign-in fails without them).
- **Version.** Bump `version:` in `pubspec.yaml` (`1.0.0+1` is name+code) for every upload.

## 2. Signing key (once, keep it safe)

```bash
keytool -genkey -v -keystore ~/fitalarm-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties`. Git already ignores it, and it must never be committed.

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/home/you/fitalarm-upload.jks
```

The release build picks this file up automatically. Turn on **Play App Signing** when you create the app: Google then holds the app signing key, and this file is only your upload key. Back up the `.jks` file and its passwords somewhere other than this laptop.

## 3. Build

```bash
flutter test
flutter build appbundle --release      # → build/app/outputs/bundle/release/app-release.aab
```

Before uploading, test the release build on a real phone (`flutter install --release`). Check:

- The alarm rings with the screen locked and the app closed, survives a reboot, and only stops after the workout.
- Strict mode: the volume keys don't lower it, pressing Home or opening another app brings the alarm back within about a second, and powering off then on rings it again after unlock.
- Each brain game (maths, memory, number order) turns the alarm off, and "Try it" works from the editor.
- The camera counts reps for each exercise in normal room light.
- Steps go up while walking and pause in a car or on a bike. A GPS walk records distance outdoors.
- Water and My Day reminders arrive on time, and their action buttons work.
- Phone OTP and Google sign-in work with the release key.
- Food scanning recognises common dishes, and "Delete account" works.

## 4. Play Console

**(you)** Create a developer account (one-time US$25). New personal accounts must run a **closed test with at least 12 testers for 14 days** before production access is granted.

### App content forms

| Form | What to declare |
|---|---|
| Privacy policy | Host `docs/PRIVACY.md` at a public URL (GitHub Pages on this repo works) and paste the link |
| Ads | No ads |
| App access | Give reviewers a way in: a test phone number and code from Firebase Auth → *Phone numbers for testing* |
| Content rating | Questionnaire: health & fitness, no user-generated content shared with others |
| Target audience | 13+ (or 18+) |
| Health apps | Category: fitness / activity tracking, nutrition. Not a medical device |
| Data safety | See below |
| Exact alarms | `USE_EXACT_ALARM`: the core function is an alarm clock |
| Full-screen intent | Alarm clock that must show over the lock screen |
| Foreground service | Media playback: the alarm sound plays until the workout is done |
| Display over other apps | Only used by the optional strict alarm mode, to bring the alarm back if the user leaves it before finishing. Requested when the user turns strict mode on |

### Data safety answers

| Data type | Collected | Shared | Purpose | Notes |
|---|---|---|---|---|
| Phone number / email, name, user ID | Yes | No | Account management | Firebase Auth |
| Photos (meal photos) | No, stays on device | No | — | Recognised on the phone; never uploaded |
| Health & fitness (weight, steps, workouts, diet) | No, stays on device | No | — | Stored locally only |
| Location | No, stays on device | No | — | Used only during GPS walks |
| Camera video (workouts) | No, on-device | No | — | ML Kit on-device |

Answer these as well: data is encrypted in transit (yes), and users can request deletion (yes: in-app "Delete account").

### Store listing **(you)**

- Icon 512×512, feature graphic 1024×500, and 4–8 phone screenshots (`docs/screenshots/` has a starting set).
- Short description, up to 80 characters. Suggestion: *An alarm that only stops when you've worked out, plus steps, water and diet in one.*
- Full description covering the workout alarm, camera rep counting, the streak calendar, My Day, verified steps, water, diet plans and the food scanner.

## 5. After launch

- Watch Firebase Crashlytics. Adding it is a small next step.
