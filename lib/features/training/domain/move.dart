/// Muscle groups the Workouts section is organised by.
enum BodyFocus {
  abs('Abs', 'Six-pack and core strength', 'crunch'),
  chest('Chest', 'Push-up power and a stronger chest', 'pushUp'),
  biceps('Biceps', 'Curls and pulls for bigger arms', 'bicepCurl'),
  triceps('Triceps', 'Firm the back of your arms', 'tricepDip'),
  shoulders('Shoulders', 'Broader, stronger shoulders', 'shoulderPress'),
  back('Back', 'Better posture, stronger back', 'superman'),
  legs('Legs', 'Strong legs, no gym needed', 'squat'),
  glutes('Glutes', 'Lift and shape your glutes', 'gluteBridge'),
  fullBody('Full body', 'Burn fat and build stamina', 'burpee');

  const BodyFocus(this.label, this.blurb, this.demo);

  final String label;
  final String blurb;

  /// The move shown animated on this focus's card.
  final String demo;
}

/// One guided exercise: an animation, how to do it, and the target muscles.
/// No camera is needed; the user taps Done or follows the timer.
class Move {
  const Move(
    this.id,
    this.name, {
    required this.muscles,
    required this.steps,
    this.focus = const {},
    this.timed = false,
    this.perSide = false,
    this.equipment,
    String? demo,
  }) : demo = demo ?? id;

  final String id;
  final String name;
  final String muscles;

  /// How to do it, in order.
  final List<String> steps;
  final Set<BodyFocus> focus;

  /// Held or done for a time rather than counted in reps.
  final bool timed;

  /// Done on the left and then the right side.
  final bool perSide;

  /// What's needed besides the floor, if anything.
  final String? equipment;

  /// Animation key (see moveDemos and the camera exercises' demos).
  final String demo;

  /// Rough seconds per rep, for time estimates.
  int get secondsPerRep => 3;
}

const _bottles = 'Water bottles or dumbbells';
const _chair = 'A sturdy chair, sofa or bed edge';

/// Every guided move, by id.
abstract final class Moves {
  // ---------------------------------------------------------------- abs
  static const crunch = Move(
    'crunch',
    'Crunches',
    muscles: 'Upper abs',
    focus: {BodyFocus.abs},
    steps: [
      'Lie on your back, knees bent, feet flat on the floor.',
      'Reach your hands towards your knees and lift your shoulders off the floor using your abs.',
      'Lower slowly. Keep your chin off your chest and breathe out as you lift.',
    ],
  );
  static const bicycleCrunch = Move(
    'bicycleCrunch',
    'Bicycle crunches',
    muscles: 'Abs, obliques',
    focus: {BodyFocus.abs},
    steps: [
      'Lie on your back with hands lightly behind your head and legs lifted.',
      'Bring one knee in while turning the opposite elbow towards it; straighten the other leg.',
      'Switch sides in a smooth pedalling motion. Each side counts as one.',
    ],
  );
  static const legRaise = Move(
    'legRaise',
    'Leg raises',
    muscles: 'Lower abs',
    focus: {BodyFocus.abs},
    steps: [
      'Lie flat with your legs straight and your hands under your hips.',
      'Keeping your legs straight, raise them until they point at the ceiling.',
      'Lower them slowly without letting your lower back arch off the floor.',
    ],
  );
  static const flutterKick = Move(
    'flutterKick',
    'Flutter kicks',
    muscles: 'Lower abs, hip flexors',
    focus: {BodyFocus.abs},
    timed: true,
    steps: [
      'Lie on your back, hands under your hips, legs straight and a few inches off the floor.',
      'Kick your legs up and down in small, quick movements.',
      'Press your lower back into the floor the whole time.',
    ],
  );
  static const reverseCrunch = Move(
    'reverseCrunch',
    'Reverse crunches',
    muscles: 'Lower abs',
    focus: {BodyFocus.abs},
    steps: [
      'Lie on your back with knees bent at 90° and lifted, arms at your sides.',
      'Curl your hips off the floor, bringing your knees towards your chest.',
      'Lower your hips slowly back down. Avoid swinging.',
    ],
  );
  static const russianTwist = Move(
    'russianTwist',
    'Russian twists',
    muscles: 'Obliques, abs',
    focus: {BodyFocus.abs},
    steps: [
      'Sit with knees bent, lean back slightly and lift your feet if you can.',
      'Hold your hands together and turn your upper body to touch the floor beside your hip.',
      'Twist to the other side. Each touch counts as one.',
    ],
  );
  static const heelTouch = Move(
    'heelTouch',
    'Heel touches',
    muscles: 'Obliques',
    focus: {BodyFocus.abs},
    steps: [
      'Lie on your back, knees bent, feet flat and shoulders slightly lifted.',
      'Reach your right hand to your right heel by bending sideways.',
      'Then reach your left hand to your left heel. Each touch counts as one.',
    ],
  );
  static const vUp = Move(
    'vUp',
    'V-ups',
    muscles: 'Whole core',
    focus: {BodyFocus.abs},
    steps: [
      'Lie flat with arms stretched overhead and legs straight.',
      'In one move, lift your legs and upper body to make a V, reaching for your toes.',
      'Lower back down with control.',
    ],
  );
  static const plank = Move(
    'plank',
    'Plank',
    muscles: 'Core, shoulders',
    focus: {BodyFocus.abs},
    timed: true,
    steps: [
      'Rest on your forearms and toes, elbows under your shoulders.',
      'Keep a straight line from head to heels; squeeze your glutes and abs.',
      "Don't let your hips sag or pike up. Breathe steadily.",
    ],
  );
  static const sidePlank = Move(
    'sidePlank',
    'Side plank',
    muscles: 'Obliques, shoulders',
    focus: {BodyFocus.abs},
    timed: true,
    perSide: true,
    steps: [
      'Lie on your side and prop yourself up on one forearm, elbow under your shoulder.',
      'Lift your hips so your body forms a straight line. Raise your top arm.',
      'Hold, then switch sides when told.',
    ],
  );
  static const mountainClimber = Move(
    'mountainClimber',
    'Mountain climbers',
    muscles: 'Core, shoulders, cardio',
    focus: {BodyFocus.abs, BodyFocus.fullBody},
    timed: true,
    steps: [
      'Start in a high plank with hands under your shoulders.',
      'Drive one knee towards your chest, then switch legs quickly.',
      'Keep your hips low and your back flat.',
    ],
  );
  static const sitUp = Move(
    'sitUp',
    'Sit-ups',
    muscles: 'Abs',
    focus: {BodyFocus.abs},
    steps: [
      'Lie on your back, knees bent, arms crossed on your chest.',
      'Sit all the way up until your chest nears your knees.',
      'Lower back down slowly.',
    ],
  );
  static const shoulderTap = Move(
    'shoulderTap',
    'Plank shoulder taps',
    muscles: 'Core, shoulders',
    focus: {BodyFocus.abs, BodyFocus.shoulders},
    steps: [
      'Start in a high plank, feet a little wider than hips.',
      'Lift one hand and tap the opposite shoulder, then put it back down.',
      'Alternate sides while keeping your hips still. Each tap counts.',
    ],
  );

  // -------------------------------------------------------------- chest
  static const pushUp = Move(
    'pushUp',
    'Push-ups',
    muscles: 'Chest, triceps, shoulders',
    focus: {BodyFocus.chest},
    steps: [
      'Hands slightly wider than your shoulders, body straight from head to heels.',
      'Lower your chest until it nearly touches the floor, elbows at about 45°.',
      'Push back up. Drop to your knees if you need to.',
    ],
  );
  static const kneePushUp = Move(
    'kneePushUp',
    'Knee push-ups',
    muscles: 'Chest, triceps',
    focus: {BodyFocus.chest},
    steps: [
      'Start on your hands and knees, then walk your hands forward so your body is straight from knees to head.',
      'Lower your chest towards the floor.',
      'Push back up, keeping your core tight.',
    ],
  );
  static const widePushUp = Move(
    'widePushUp',
    'Wide push-ups',
    muscles: 'Outer chest, shoulders',
    focus: {BodyFocus.chest},
    demo: 'pushUp',
    steps: [
      'Place your hands much wider than your shoulders.',
      'Lower your chest towards the floor, keeping your body straight.',
      'Push back up. You will feel it more in your chest.',
    ],
  );
  static const inclinePushUp = Move(
    'inclinePushUp',
    'Incline push-ups',
    muscles: 'Lower chest, triceps',
    focus: {BodyFocus.chest},
    equipment: 'A bed, sofa or table',
    steps: [
      'Put your hands on the edge of a bed, sofa or sturdy table.',
      'Walk your feet back until your body is straight.',
      'Lower your chest to the edge and push back up. Easier than floor push-ups.',
    ],
  );
  static const declinePushUp = Move(
    'declinePushUp',
    'Decline push-ups',
    muscles: 'Upper chest, shoulders',
    focus: {BodyFocus.chest},
    equipment: 'A step, chair or bed',
    steps: [
      'Put your feet up on a step, chair or bed, hands on the floor.',
      'Lower your chest towards the floor, keeping your body straight.',
      'Push back up. Harder than normal push-ups.',
    ],
  );
  static const hinduPushUp = Move(
    'hinduPushUp',
    'Hindu push-ups',
    muscles: 'Chest, shoulders, back',
    focus: {BodyFocus.chest, BodyFocus.shoulders},
    steps: [
      'Start with hips high in an upside-down V.',
      'Swoop your chest down close to the floor and forward between your hands.',
      'Finish looking up with arms straight, then push your hips back up to the V.',
    ],
  );
  static const diamondPushUp = Move(
    'diamondPushUp',
    'Diamond push-ups',
    muscles: 'Triceps, inner chest',
    focus: {BodyFocus.triceps, BodyFocus.chest},
    demo: 'pushUp',
    steps: [
      'Place your hands close together under your chest, thumbs and index fingers touching in a diamond.',
      'Lower your chest to your hands, elbows close to your body.',
      'Push back up. Do them from your knees if needed.',
    ],
  );

  // ------------------------------------------------------------- biceps
  static const bicepCurl = Move(
    'bicepCurl',
    'Biceps curls',
    muscles: 'Biceps',
    focus: {BodyFocus.biceps},
    equipment: _bottles,
    steps: [
      'Stand tall holding a bottle or dumbbell in each hand, palms facing forward.',
      'Keeping your elbows at your sides, curl the weights up to your shoulders.',
      'Lower slowly all the way down. Don’t swing your body.',
    ],
  );
  static const hammerCurl = Move(
    'hammerCurl',
    'Hammer curls',
    muscles: 'Biceps, forearms',
    focus: {BodyFocus.biceps},
    equipment: _bottles,
    demo: 'bicepCurl',
    steps: [
      'Hold the weights at your sides with palms facing each other.',
      'Curl them up to your shoulders, keeping your palms facing in.',
      'Lower slowly.',
    ],
  );
  static const concentrationCurl = Move(
    'concentrationCurl',
    'Concentration curls',
    muscles: 'Biceps',
    focus: {BodyFocus.biceps},
    equipment: _bottles,
    perSide: true,
    steps: [
      'Sit on a chair, lean forward and rest your elbow on the inside of your thigh.',
      'Curl the weight up towards your shoulder.',
      'Lower it slowly. Finish one arm, then the other.',
    ],
  );
  static const towelCurl = Move(
    'towelCurl',
    'Towel curls',
    muscles: 'Biceps',
    focus: {BodyFocus.biceps},
    equipment: 'A towel',
    perSide: true,
    steps: [
      'Stand on the middle of a towel with one foot and hold both ends.',
      'Curl your hands up while pressing your foot down to make it harder.',
      'Lower slowly. No weights needed.',
    ],
  );
  static const curlHold = Move(
    'curlHold',
    'Biceps curl hold',
    muscles: 'Biceps',
    focus: {BodyFocus.biceps},
    equipment: _bottles,
    timed: true,
    steps: [
      'Hold the weights with elbows at your sides.',
      'Curl halfway up so your forearms are level with the floor.',
      'Hold still and squeeze your biceps.',
    ],
  );
  static const doorwayRow = Move(
    'doorwayRow',
    'Doorway rows',
    muscles: 'Back, biceps',
    focus: {BodyFocus.biceps, BodyFocus.back},
    equipment: 'A sturdy door frame',
    steps: [
      'Stand in a doorway, hold the frame at chest height and lean back with straight arms.',
      'Pull your chest towards the frame by bending your elbows and squeezing your shoulder blades.',
      'Lower back slowly. Walk your feet forward to make it harder.',
    ],
  );

  // ------------------------------------------------------------ triceps
  static const tricepDip = Move(
    'tricepDip',
    'Triceps dips',
    muscles: 'Triceps, shoulders',
    focus: {BodyFocus.triceps},
    equipment: _chair,
    steps: [
      'Sit on the edge of a chair, hands beside your hips, then slide your hips off.',
      'Bend your elbows straight back to about 90°, lowering your hips.',
      'Press back up until your arms are straight.',
    ],
  );
  static const overheadExtension = Move(
    'overheadExtension',
    'Overhead triceps extension',
    muscles: 'Triceps',
    focus: {BodyFocus.triceps},
    equipment: 'A water bottle or dumbbell',
    steps: [
      'Hold one bottle with both hands above your head.',
      'Lower it behind your head by bending your elbows; keep elbows pointing up.',
      'Straighten your arms to lift it back up.',
    ],
  );
  static const tricepKickback = Move(
    'tricepKickback',
    'Triceps kickbacks',
    muscles: 'Triceps',
    focus: {BodyFocus.triceps},
    equipment: _bottles,
    steps: [
      'Hold the weights, bend your knees slightly and lean forward with a flat back.',
      'Keep your upper arms close to your body and straighten your elbows to push the weights back.',
      'Bend your elbows to bring them back down.',
    ],
  );
  static const closeKneePushUp = Move(
    'closeKneePushUp',
    'Close-grip knee push-ups',
    muscles: 'Triceps, chest',
    focus: {BodyFocus.triceps},
    demo: 'kneePushUp',
    steps: [
      'From your knees, place your hands under your shoulders.',
      'Lower down with your elbows brushing your sides.',
      'Push back up.',
    ],
  );
  static const plankUpDown = Move(
    'plankUpDown',
    'Plank up-downs',
    muscles: 'Triceps, core',
    focus: {BodyFocus.triceps, BodyFocus.abs},
    steps: [
      'Start in a forearm plank.',
      'Push up onto one hand, then the other, to a high plank.',
      'Lower back down to your forearms one arm at a time. Keep your hips still.',
    ],
  );

  // ---------------------------------------------------------- shoulders
  static const shoulderPress = Move(
    'shoulderPress',
    'Shoulder press',
    muscles: 'Shoulders, triceps',
    focus: {BodyFocus.shoulders},
    equipment: _bottles,
    steps: [
      'Hold the weights at shoulder height, palms facing forward.',
      'Press them straight overhead until your arms are straight.',
      'Lower back to your shoulders slowly.',
    ],
  );
  static const lateralRaise = Move(
    'lateralRaise',
    'Lateral raises',
    muscles: 'Side shoulders',
    focus: {BodyFocus.shoulders},
    equipment: _bottles,
    steps: [
      'Stand holding the weights at your sides.',
      'With a slight bend in your elbows, raise your arms out to shoulder height.',
      'Lower slowly. Don’t shrug.',
    ],
  );
  static const frontRaise = Move(
    'frontRaise',
    'Front raises',
    muscles: 'Front shoulders',
    focus: {BodyFocus.shoulders},
    equipment: _bottles,
    steps: [
      'Hold the weights in front of your thighs.',
      'Raise them straight in front of you to shoulder height.',
      'Lower slowly.',
    ],
  );
  static const pikePushUp = Move(
    'pikePushUp',
    'Pike push-ups',
    muscles: 'Shoulders, triceps',
    focus: {BodyFocus.shoulders},
    steps: [
      'Start in an upside-down V with hips high and hands shoulder-width apart.',
      'Bend your elbows to lower the top of your head towards the floor.',
      'Push back up.',
    ],
  );
  static const armCircles = Move(
    'armCircles',
    'Arm circles',
    muscles: 'Shoulders',
    focus: {BodyFocus.shoulders},
    timed: true,
    steps: [
      'Stand and raise your arms out to the sides at shoulder height.',
      'Make small circles forwards.',
      'Halfway through, switch to circling backwards.',
    ],
  );
  static const yRaise = Move(
    'yRaise',
    'Prone Y raises',
    muscles: 'Upper back, shoulders',
    focus: {BodyFocus.shoulders, BodyFocus.back},
    steps: [
      'Lie face down with your arms stretched overhead in a Y shape, thumbs up.',
      'Lift your arms off the floor by squeezing your shoulder blades.',
      'Hold for a second, then lower.',
    ],
  );

  // --------------------------------------------------------------- back
  static const superman = Move(
    'superman',
    'Superman',
    muscles: 'Lower back, glutes',
    focus: {BodyFocus.back},
    steps: [
      'Lie face down with arms stretched in front of you.',
      'Lift your arms, chest and legs off the floor at the same time.',
      'Hold for a second at the top, then lower slowly.',
    ],
  );
  static const birdDog = Move(
    'birdDog',
    'Bird dog',
    muscles: 'Lower back, core',
    focus: {BodyFocus.back, BodyFocus.abs},
    steps: [
      'Start on your hands and knees.',
      'Reach one arm forward and the opposite leg back until both are straight.',
      'Return and switch sides. Keep your back flat. Each side counts.',
    ],
  );
  static const snowAngel = Move(
    'snowAngel',
    'Reverse snow angels',
    muscles: 'Upper back, shoulders',
    focus: {BodyFocus.back},
    steps: [
      'Lie face down with your arms by your sides, palms down, slightly off the floor.',
      'Sweep your arms in a wide arc over your head, keeping them off the floor.',
      'Sweep back down to your sides.',
    ],
  );

  // --------------------------------------------------------------- legs
  static const squat = Move(
    'squat',
    'Squats',
    muscles: 'Quads, glutes',
    focus: {BodyFocus.legs},
    steps: [
      'Stand with feet shoulder-width apart.',
      'Push your hips back and bend your knees as if sitting in a chair, chest up.',
      'Go as low as is comfortable, then stand back up through your heels.',
    ],
  );
  static const lunge = Move(
    'lunge',
    'Lunges',
    muscles: 'Quads, glutes',
    focus: {BodyFocus.legs, BodyFocus.glutes},
    steps: [
      'Stand tall, then step forward with one leg.',
      'Lower until both knees are bent at about 90°; back knee near the floor.',
      'Push back to standing and switch legs. Each leg counts.',
    ],
  );
  static const reverseLunge = Move(
    'reverseLunge',
    'Reverse lunges',
    muscles: 'Glutes, quads',
    focus: {BodyFocus.legs, BodyFocus.glutes},
    demo: 'lunge',
    steps: [
      'Stand tall and step one foot back.',
      'Lower until your front thigh is level with the floor.',
      'Push through your front heel to stand up. Alternate legs.',
    ],
  );
  static const jumpSquat = Move(
    'jumpSquat',
    'Jump squats',
    muscles: 'Legs, cardio',
    focus: {BodyFocus.legs, BodyFocus.fullBody},
    steps: [
      'Squat down with your chest up.',
      'Jump up explosively, reaching your arms down.',
      'Land softly and go straight into the next squat.',
    ],
  );
  static const sumoSquat = Move(
    'sumoSquat',
    'Sumo squats',
    muscles: 'Inner thighs, glutes',
    focus: {BodyFocus.legs, BodyFocus.glutes},
    steps: [
      'Stand with feet wide and toes turned out.',
      'Lower your hips straight down, keeping your knees over your toes.',
      'Squeeze your glutes to stand back up.',
    ],
  );
  static const sideLunge = Move(
    'sideLunge',
    'Side lunges',
    muscles: 'Inner thighs, glutes',
    focus: {BodyFocus.legs},
    steps: [
      'Stand with feet wide apart.',
      'Bend one knee and push your hips back over that leg, keeping the other leg straight.',
      'Push back to the middle and switch sides. Each side counts.',
    ],
  );
  static const calfRaise = Move(
    'calfRaise',
    'Calf raises',
    muscles: 'Calves',
    focus: {BodyFocus.legs},
    steps: [
      'Stand tall, holding a wall for balance if needed.',
      'Rise up onto your toes as high as you can.',
      'Lower your heels slowly.',
    ],
  );
  static const wallSit = Move(
    'wallSit',
    'Wall sit',
    muscles: 'Quads',
    focus: {BodyFocus.legs},
    timed: true,
    equipment: 'A wall',
    steps: [
      'Lean your back against a wall and slide down until your knees are at about 90°.',
      'Keep your knees over your ankles and your back flat on the wall.',
      'Hold.',
    ],
  );

  // ------------------------------------------------------------- glutes
  static const gluteBridge = Move(
    'gluteBridge',
    'Glute bridges',
    muscles: 'Glutes, hamstrings',
    focus: {BodyFocus.glutes},
    steps: [
      'Lie on your back with knees bent and feet flat, close to your hips.',
      'Squeeze your glutes and lift your hips until your body is straight from knees to shoulders.',
      'Pause, then lower slowly.',
    ],
  );
  static const singleLegBridge = Move(
    'singleLegBridge',
    'Single-leg bridges',
    muscles: 'Glutes, hamstrings',
    focus: {BodyFocus.glutes},
    perSide: true,
    steps: [
      'Lie on your back, one knee bent and the other leg straight.',
      'Push through the bent leg’s heel to lift your hips.',
      'Lower slowly. Finish one side, then the other.',
    ],
  );
  static const donkeyKick = Move(
    'donkeyKick',
    'Donkey kicks',
    muscles: 'Glutes',
    focus: {BodyFocus.glutes},
    perSide: true,
    steps: [
      'Start on your hands and knees.',
      'Keeping the knee bent, lift one leg until your thigh is level with your back, sole facing the ceiling.',
      'Lower without touching the floor. Finish one side, then the other.',
    ],
  );
  static const gluteKickback = Move(
    'gluteKickback',
    'Glute kickbacks',
    muscles: 'Glutes, hamstrings',
    focus: {BodyFocus.glutes},
    perSide: true,
    steps: [
      'Start on your hands and knees.',
      'Straighten one leg back and lift it to hip height.',
      'Lower and repeat. Finish one side, then the other.',
    ],
  );

  // ---------------------------------------------------------- full body
  static const jumpingJack = Move(
    'jumpingJack',
    'Jumping jacks',
    muscles: 'Full body, cardio',
    focus: {BodyFocus.fullBody},
    timed: true,
    steps: [
      'Stand with feet together and arms at your sides.',
      'Jump your feet out wide while raising your arms overhead.',
      'Jump back to the start. Keep a steady rhythm.',
    ],
  );
  static const highKnees = Move(
    'highKnees',
    'High knees',
    muscles: 'Legs, cardio',
    focus: {BodyFocus.fullBody},
    timed: true,
    steps: [
      'Run on the spot.',
      'Drive each knee up to hip height.',
      'Pump your arms and stay on the balls of your feet.',
    ],
  );
  static const burpee = Move(
    'burpee',
    'Burpees',
    muscles: 'Full body',
    focus: {BodyFocus.fullBody},
    steps: [
      'From standing, squat and place your hands on the floor.',
      'Jump your feet back into a plank, then jump them back in.',
      'Stand up and jump with your arms overhead.',
    ],
  );
  static const buttKicks = Move(
    'buttKicks',
    'Butt kicks',
    muscles: 'Hamstrings, cardio',
    focus: {BodyFocus.fullBody},
    timed: true,
    steps: ['Jog on the spot.', 'Kick your heels up towards your glutes.', 'Keep a quick pace and pump your arms.'],
  );
  static const skater = Move(
    'skater',
    'Skater hops',
    muscles: 'Legs, glutes, cardio',
    focus: {BodyFocus.fullBody, BodyFocus.glutes},
    timed: true,
    steps: [
      'Hop sideways onto your right foot, swinging your left leg behind you.',
      'Hop back onto your left foot, swinging your right leg behind.',
      'Keep your knees soft and land gently.',
    ],
  );
  static const inchworm = Move(
    'inchworm',
    'Inchworms',
    muscles: 'Full body, hamstrings',
    focus: {BodyFocus.fullBody},
    steps: [
      'Stand tall, then bend forward and put your hands on the floor.',
      'Walk your hands out to a plank.',
      'Walk your hands back to your feet and stand up.',
    ],
  );
  static const punches = Move(
    'punches',
    'Boxing punches',
    muscles: 'Arms, shoulders, cardio',
    focus: {BodyFocus.fullBody, BodyFocus.shoulders},
    timed: true,
    steps: [
      'Stand with knees soft and fists up by your chin.',
      'Punch straight forward with one arm, then the other, turning your body slightly.',
      'Keep your guard up and go fast.',
    ],
  );

  // ------------------------------------------------- warm-up & stretch
  static const march = Move(
    'march',
    'March on the spot',
    muscles: 'Warm-up',
    timed: true,
    steps: ['March on the spot, lifting your knees.', 'Swing your arms naturally.', 'Breathe deeply and get warm.'],
  );
  static const catCow = Move(
    'catCow',
    'Cat-cow stretch',
    muscles: 'Spine',
    timed: true,
    steps: [
      'Start on your hands and knees.',
      'Breathe in as you drop your belly and look up.',
      'Breathe out as you round your back and tuck your chin. Move slowly.',
    ],
  );
  static const cobra = Move(
    'cobra',
    'Cobra stretch',
    muscles: 'Abs, lower back',
    timed: true,
    steps: [
      'Lie face down with your hands under your shoulders.',
      'Press up gently, lifting your chest while your hips stay down.',
      'Relax your shoulders and breathe.',
    ],
  );
  static const childPose = Move(
    'childPose',
    "Child's pose",
    muscles: 'Back, hips',
    timed: true,
    steps: [
      'Kneel and sit back on your heels.',
      'Fold forward and stretch your arms out in front on the floor.',
      'Rest your forehead down and breathe slowly.',
    ],
  );
  static const hamstringStretch = Move(
    'hamstringStretch',
    'Seated hamstring stretch',
    muscles: 'Hamstrings, back',
    timed: true,
    steps: [
      'Sit with your legs straight in front of you.',
      'Reach for your toes, folding from your hips.',
      'Go only as far as is comfortable and breathe.',
    ],
  );
  static const quadStretch = Move(
    'quadStretch',
    'Standing quad stretch',
    muscles: 'Quads',
    timed: true,
    perSide: true,
    steps: [
      'Stand on one leg; hold a wall if needed.',
      'Pull the other heel towards your glutes, knees together.',
      'Hold, then switch sides when told.',
    ],
  );
  static const toeTouch = Move(
    'toeTouch',
    'Standing toe touches',
    muscles: 'Hamstrings, back',
    steps: [
      'Stand tall with your arms overhead.',
      'Fold forward and reach towards your toes, knees soft.',
      'Roll back up slowly.',
    ],
  );
  static const lungeStretch = Move(
    'lungeStretch',
    'Hip flexor stretch',
    muscles: 'Hips, quads',
    timed: true,
    perSide: true,
    steps: [
      'Step into a low lunge with your back knee on the floor.',
      'Push your hips gently forward until you feel a stretch at the front of the back hip.',
      'Hold, then switch sides when told.',
    ],
  );

  static const all = [
    crunch,
    bicycleCrunch,
    legRaise,
    flutterKick,
    reverseCrunch,
    russianTwist,
    heelTouch,
    vUp,
    plank,
    sidePlank,
    mountainClimber,
    sitUp,
    shoulderTap,
    pushUp,
    kneePushUp,
    widePushUp,
    inclinePushUp,
    declinePushUp,
    hinduPushUp,
    diamondPushUp,
    bicepCurl,
    hammerCurl,
    concentrationCurl,
    towelCurl,
    curlHold,
    doorwayRow,
    tricepDip,
    overheadExtension,
    tricepKickback,
    closeKneePushUp,
    plankUpDown,
    shoulderPress,
    lateralRaise,
    frontRaise,
    pikePushUp,
    armCircles,
    yRaise,
    superman,
    birdDog,
    snowAngel,
    squat,
    lunge,
    reverseLunge,
    jumpSquat,
    sumoSquat,
    sideLunge,
    calfRaise,
    wallSit,
    gluteBridge,
    singleLegBridge,
    donkeyKick,
    gluteKickback,
    jumpingJack,
    highKnees,
    burpee,
    buttKicks,
    skater,
    inchworm,
    punches,
    march,
    catCow,
    cobra,
    childPose,
    hamstringStretch,
    quadStretch,
    toeTouch,
    lungeStretch,
  ];

  /// Warm-ups and stretches (no body focus).
  static const stretches = [march, catCow, cobra, childPose, hamstringStretch, quadStretch, toeTouch, lungeStretch];
}
