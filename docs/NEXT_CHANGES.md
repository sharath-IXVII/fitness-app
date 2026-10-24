# Next changes (waiting for the go-ahead)

Requested by the owner; do not start until they say go.

1. **Arc calendar.** In every arc, ALL days of all three months start covered by the arc's lock
   (Winter: ice blocks) with the number hidden. Completing the day breaks the block and reveals the number.
   Today the numbers are visible through the lock.
2. **Steps.** One merged step count. Use accelerometer + gyroscope, and add GPS when the user allows
   location; without GPS use the motion sensors only. No separate "phone sensor / GPS walk" rows in the UI.
   Show kilometres too. From the user's height and weight, give a daily steps and kilometres target
   (to burn calories).
3. **Water.** Daily target from weight plus the current season; custom amount the user can add.
4. **Levels.** The 12 arc badges per year complete Level 1 (Starter, 100 XP, per the owner). Define ALL later
   levels and their XP up front, so no app update is needed. Show XP needed for each level.
5. **Workouts tab.** Redesign from a reference theme the owner will provide.
6. **Notifications.** Friendlier, motivating tone.
7. **Food camera.** The "pick the dish" step is unclear; it often cannot tell what the dish is (e.g. chapati)
   and shows no carbs or protein. Fix identification and show calories, carbs, protein, fat.
8. **Opening animation.** Too fast: the "Sponsored by GetYr_io" line is not seen. Slow it down, and make
   the hand-off from the launch screen to the app look consistent (outside view to inside view).
9. Everything else is fine as it is.
10. **Remove phone-number sign-in** from the UI (Google sign-in only).
11. **Cloud backup of progress.** Everything earned under a Google account (XP, level, arc badges, streak and
    day history, goals) is stored in Firestore under `users/{uid}` and restored when the same account signs in
    on any phone. Needs: new Firestore rules for the synced data (owner re-publishes them), merge rules so a
    fresh install never overwrites better cloud data, an update to the privacy policy and the Play data-safety
    answers, and tests (rules emulator + restore flow).
