/// The privacy policy shown in the app. Keep in sync with docs/privacy.md,
/// which is the version to host publicly for the Play Store listing.
const privacyUpdated = 'November 2026';

const privacySections = <(String, String)>[
  (
    'Summary',
    'FittArc keeps your fitness data on your phone and backs your progress up to your account, so you never lose '
        'your levels and badges. Three things leave your device: what\'s needed to sign you in, that progress '
        'backup, and, if you use Friends, a small public profile and your challenges. We don\'t sell data, show ads '
        'or use third-party analytics.',
  ),
  (
    'Your account',
    'You sign in with Google. Firebase Authentication (Google) stores your email address, your name if Google '
        'provides it, and a user ID. This is used only to sign you in.',
  ),
  (
    'Progress backup',
    'So that your hard-earned levels, badges and streaks survive a lost phone or a reinstall, Cloud Firestore '
        '(Google) stores, under your account only: your profile (name, age, gender, height, weight, goal, '
        'activity level, diet and wake and sleep times), one entry per day (workout done, water, steps, meals '
        'logged and protein), the badges you have earned, the date you started and your water goal. Only you can '
        'read it; it is used to restore your progress when you sign in on a new phone, and nothing else. It is '
        'deleted when you delete your account.',
  ),
  (
    'Friends and challenges',
    'If you use Friends, Cloud Firestore (Google) stores a public profile that your friends can see: your name, '
        'your best arc badge, level and XP, current and best streak, active days in the current arc and workouts '
        'this week. It also stores your friend list, people you blocked, challenges you send or join (names, '
        'exercise, target and whether each of you finished) and reports you make. It also stores your friend code '
        '(a short random code that lets someone find you to send a friend request) and the friend requests you send '
        'or receive (the sender\'s name and badge title). Anyone you give a challenge code to can see that '
        'challenge. Nothing else (weight, meals, photos, location, health details) is shared.',
  ),
  (
    'Clubs',
    'If you create or join a club, Cloud Firestore stores the club\'s name, description and type, who started it, '
        'its members\' names, and the text messages sent in it. Every signed-in user can see a club\'s name and '
        'description; only members can read its chat. Messages are text only (no photos or links) and are deleted '
        'automatically 24 hours after they are sent. You can delete your own messages, leave a club, report a '
        'message or block a person at any time; the person who started a club can remove messages and members. '
        'Club admins can set challenges such as "Run 8 km", optionally with a start point (a location). When you '
        'do a challenge, FittArc uses your phone\'s location only while it runs, to measure the distance, also '
        'with the screen off (a notification shows it is on). Your route stays on your phone; only your name, '
        'time and distance are shared with the club for the ranking.',
  ),
  (
    'Teams and snaps to friends',
    'If you join a team streak, Cloud Firestore stores the team name, its members\' names and, for each day, '
        'which members hit their goals (nothing else about the day). If you send a food snap to friends inside '
        'FittArc, a small picture of the snap and a short caption are stored for the friends you pick and deleted '
        'after 24 hours. Runs, walks and rides you track on your own, and your body-check measurements, stay on '
        'your phone.',
  ),
  (
    'Data stored on your phone',
    'Alarms, routines, your My Day plan, weigh-ins, weight goal, saved foods, meal photos, and the pulse, breathing and mood '
        'records you save in the Health tab are stored only on your device and are not backed up, so they are not restored on a new phone. Your progress backup (above) '
        'is kept in your account. Uninstalling the app or using "Reset data on this device" removes what is on the '
        'phone.',
  ),
  (
    'Health readings',
    'The Health tab keeps the resting pulse you save from the camera heart-rate estimate, your breathing-exercise '
        'minutes, breathing-rate checks (you tap each breath) and mood and energy check-ins. These are approximate '
        'wellness records for your own tracking, not medical measurements, and FittArc does not diagnose anything. '
        'They stay on your phone, are never uploaded, and are removed when you delete your account or reset data.',
  ),
  (
    'Feedback emails',
    'If you write to us from the app, your email app sends the message to support@fittarc.in. We read it to '
        'improve FittArc and to reply to you; we don\'t share it.',
  ),
  (
    'Camera during workouts',
    'The workout camera counts reps using on-device pose detection (Google ML Kit). The heart-rate estimate in the '
        'Health tab uses the back camera and flash to see the light change with your pulse under your fingertip. '
        'Video and camera images are processed in memory only and are never recorded, stored or uploaded.',
  ),
  (
    'Watches and Health Connect',
    'If you choose to connect a watch, FittArc can read its live heart rate over Bluetooth. It only looks for '
        'devices that share heart rate, and it does not use Bluetooth to find your location. If you allow it, FittArc '
        'can also read your steps, heart rate and sleep from Android Health Connect, which your watch app fills in. '
        'FittArc only reads, never writes, and never shares or uploads this data. It is shown on your phone, '
        'and the Arc minutes you earn are kept on your phone only. You can switch this off at any time in Health '
        'Connect or your phone settings.',
  ),
  (
    'Food photos',
    'Food scanning happens entirely on your phone using a built-in recognition model. Meal photos are kept only '
        'on your phone, next to the meal you logged. Help improve food recognition (optional, off by default): if you '
        'turn this on in the food scanner, each meal you log sends a small cut-out (at most 256 pixels) of every dish '
        'with the dish name you confirmed and how sure the app was, to Cloud Firestore (Google), linked to your '
        'account id. We use these only to train FittArc\'s food recognition. The full photo, your location and any '
        'other details are never sent. You can turn it off at any time; to have samples you already shared deleted, '
        'write to support@fittarc.in.',
  ),
  (
    'Steps, activity and location',
    'Step counts and activity recognition (walking, cycling, in a vehicle) come from your phone\'s motion sensors '
        '(step counter, accelerometer, gyroscope) and stay on your device; only the daily step total is part of the '
        'progress backup. Location is optional: if you turn on "Use GPS for better distance", GPS '
        'is used while the app is open to measure distance and improve step counts. Positions are processed on the '
        'phone and are never stored or sent anywhere.',
  ),
  (
    'Notifications and alarms',
    'Alarms and reminders are scheduled locally on your phone. No notification content is sent to a server.',
  ),
  (
    'Deleting your data',
    'Use "Delete account" in your profile (tap your picture on Today) to permanently delete your sign-in, your '
        'progress backup, your Friends profile, friend list and challenges, your club memberships and messages (and clubs you started), and all FittArc data on the phone. You can also email us '
        'to have your account deleted.',
  ),
  ('Children', 'FittArc is not directed at children under 13.'),
  (
    'Contact',
    'Questions or requests: support@fittarc.in. We\'ll update this page if anything changes and show the new '
        'date at the top.',
  ),
];
