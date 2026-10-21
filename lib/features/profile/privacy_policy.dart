/// The privacy policy shown in the app. Keep in sync with docs/PRIVACY.md,
/// which is the version to host publicly for the Play Store listing.
const privacyUpdated = 'October 2026';

const privacySections = <(String, String)>[
  (
    'Summary',
    'FitAlarm keeps your fitness data on your phone. We only send data off your device to sign you in and, '
        'if you use it, to analyse a meal photo. We don\'t sell data, show ads or use third-party analytics.',
  ),
  (
    'Your account',
    'When you sign in with your phone number or Google, Firebase Authentication (Google) stores your phone '
        'number or email address, your name if Google provides it, and a user ID. This is used only to sign you in.',
  ),
  (
    'Data stored on your phone',
    'Your profile (age, height, weight, goal, diet), daily logs (workouts, water, steps, meals, protein), alarms, '
        'routines, your My Day plan, weigh-ins and weight goal are stored only on your device. Uninstalling the app '
        'or using "Reset data on this device" removes them.',
  ),
  (
    'Camera during workouts',
    'The workout camera counts reps using on-device pose detection (Google ML Kit). Video is processed in memory '
        'and is never recorded, stored or uploaded.',
  ),
  (
    'Food photos',
    'When you scan a meal, the photo and any note you type are sent over an encrypted connection to our server '
        '(Google Cloud Functions) and to Anthropic, which provides the AI model that estimates nutrition. We don\'t '
        'store the photo. Anthropic processes it under its commercial terms and does not use it to train its models. '
        'We keep a daily count of scans per account to limit use.',
  ),
  (
    'Steps, activity and location',
    'Step counts and activity recognition (walking, cycling, in a vehicle) come from your phone\'s sensors and '
        'stay on your device. Location is used only while you record a GPS walk, to measure distance, and is not '
        'stored or sent anywhere.',
  ),
  (
    'Notifications and alarms',
    'Alarms and reminders are scheduled locally on your phone. No notification content is sent to a server.',
  ),
  (
    'Deleting your data',
    'Use "Delete account" in the Me tab to permanently delete your sign-in and clear all data on the device. '
        'Your scan counters on our server are deleted with your account.',
  ),
  ('Children', 'FitAlarm is not directed at children under 13.'),
  (
    'Contact',
    'Questions or requests: [your contact email]. We\'ll update this page if anything changes and show the new '
        'date at the top.',
  ),
];
