# FittArc: ideas for the next version (captured 2026-11-02, nothing built yet)

Owner's inputs, kept as written, with notes on what each one needs.

## 1. Diet camera (extend what exists)
- Photo of food gives the food name plus approximate protein/carbs/fat. Approximate is fine, keep the Beta label.
- Share the result to Instagram stories and other apps (share sheet).
- Needs: a share card image (logo + dish + numbers), `share_plus` (already in the app).

## 2. Friends become a messaging feature
- Friend by code, or by finishing a challenge together (already built).
- Pick a partner, or make a group, to go to workouts together.
- Ego nudges: if one partner is burning calories and keeping streaks, the other gets a push such as
  "Sharath finished today's goals. What are you doing?" (make it opt-in, easy to mute).
- Partner / group challenges, for example a Winter Arc challenge together. If one person breaks it, the group badge is lost for everyone.
- Needs: chat storage in Firestore, report and block, mute, rules, content rating and Data safety updates
  (user-to-user text turns on Google's user-generated-content policy: reporting, blocking, moderation).

## 3. Activities: running, cycling, walking, skipping (workouts stay)
- Walking keeps the same step logic as today.
- Running / cycling / walking: ask the user to switch GPS on, track the route, show distance, time, calories and a map of where they went.
- Needs: location permission with a clear reason, foreground service for tracking with the screen off, a map
  (OpenStreetMap needs no billing; Google Maps needs an API key), and a Play location declaration.
- Skipping: count with the motion sensor or the camera, no GPS.

## 4. Daily report
- A notification every evening: diet covered, calories eaten and burnt, steps, activities.

## 5. Body scan at the start
- Capture the body with the camera; estimate body shape, body fat and endurance level from the photo, height and weight.
- Privacy: keep everything on the phone, never upload, delete the photo after use, say so in the policy.
- Careful with the wording: no medical claims ("you will get a heart attack"). Use wellness language
  ("a fitter body is good for your heart"). Medical claims would count as a medical app, which a personal developer account cannot publish.
- Estimating body fat from a photo is approximate. Label it as an estimate, like the heart rate.

## 6. Watch-first onboarding
- At the start, invite the user to connect a watch (with a Skip button).
- Reading GPS routes and continuous data from a watch is possible through Health Connect (exercise routes), not through plain Bluetooth.

## 7. For all ages, including grandparents
- Larger text option, simple mode, high contrast, fewer steps on each screen, clear labels, voice-friendly alarms.

## 8. Workout section: body map
- A human figure that shows which muscles each exercise works (biceps: arm and shoulder, and so on), highlighted while the exercise plays.
- Start as a 2D body diagram with highlighted muscles (reliable and light). A full 3D human is a bigger job.

## Account type check (personal Play developer account)
- Fine on a personal account: items 1, 3, 4, 7, 8, watch onboarding, friends and group challenges, chat (with moderation), body scan as a wellness estimate.
- Not allowed on a personal account: anything declared under "Medical" in the Health apps declaration, for example blood pressure,
  blood sugar or oxygen logging, or health-risk predictions. Those three logs were removed on 2026-11-09.
