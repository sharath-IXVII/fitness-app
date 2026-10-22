import 'exercise_demo.dart';

/// Stick-figure keyframes for the guided moves in the Workouts section.
///
/// Side view conventions (see [sidePose]): standing figures face right;
/// figures on the floor lie with the head to the left.
final Map<String, DemoSpec> moveDemos = {
  // ------------------------------------------------------------------ abs
  'crunch': DemoSpec(DemoView.side, [
    sidePose(torso: 180, thigh: 315, shin: 45, upper: 0, fore: 0),
    sidePose(torso: 207, thigh: 315, shin: 45, upper: 345, fore: 345),
  ]),
  'bicycleCrunch': DemoSpec(DemoView.side, [
    sidePose(torso: 203, thigh: 290, shin: 15, thighF: 350, shinF: 350, upper: 225, fore: 330),
    sidePose(torso: 203, thigh: 350, shin: 350, thighF: 290, shinF: 15, upper: 225, fore: 330),
  ], cycle: const Duration(milliseconds: 1400)),
  'legRaise': DemoSpec(DemoView.side, [
    sidePose(torso: 180, thigh: 355, shin: 355, upper: 0, fore: 0),
    sidePose(torso: 180, thigh: 275, shin: 275, upper: 0, fore: 0),
  ], cycle: const Duration(milliseconds: 2200)),
  'flutterKick': DemoSpec(DemoView.side, [
    sidePose(torso: 185, thigh: 335, shin: 335, thighF: 355, shinF: 355, upper: 0, fore: 0),
    sidePose(torso: 185, thigh: 355, shin: 355, thighF: 335, shinF: 335, upper: 0, fore: 0),
  ], cycle: const Duration(milliseconds: 700)),
  'reverseCrunch': DemoSpec(DemoView.side, [
    sidePose(torso: 180, thigh: 300, shin: 20, upper: 0, fore: 0),
    sidePose(torso: 180, thigh: 235, shin: 305, upper: 0, fore: 0),
  ]),
  'russianTwist': DemoSpec(DemoView.side, [
    sidePose(torso: 240, thigh: 320, shin: 40, upper: 340, fore: 10, upperF: 60, foreF: 120),
    sidePose(torso: 240, thigh: 320, shin: 40, upper: 60, fore: 120, upperF: 340, foreF: 10),
  ], cycle: const Duration(milliseconds: 1400)),
  'heelTouch': DemoSpec(DemoView.side, [
    sidePose(torso: 197, thigh: 315, shin: 45, upper: 8, fore: 12, upperF: 22, foreF: 30),
    sidePose(torso: 197, thigh: 315, shin: 45, upper: 22, fore: 30, upperF: 8, foreF: 12),
  ], cycle: const Duration(milliseconds: 1000)),
  'vUp': DemoSpec(DemoView.side, [
    sidePose(torso: 180, thigh: 0, shin: 0, upper: 180, fore: 180),
    sidePose(torso: 235, thigh: 305, shin: 305, upper: 300, fore: 300),
  ], cycle: const Duration(milliseconds: 2000)),
  'sidePlank': DemoSpec(DemoView.side, [
    sidePose(torso: 192, thigh: 3, shin: 3, upper: 90, fore: 180, upperF: 270, foreF: 270),
    sidePose(torso: 192.5, thigh: 3.5, shin: 3.5, upper: 90, fore: 180, upperF: 268, foreF: 268),
  ], cycle: const Duration(milliseconds: 2400)),
  'shoulderTap': DemoSpec(DemoView.side, [
    sidePose(torso: 192, thigh: 4, shin: 4, upper: 90, fore: 90),
    sidePose(torso: 192, thigh: 4, shin: 4, upper: 90, fore: 90, upperF: 120, foreF: 300),
  ], cycle: const Duration(milliseconds: 1100)),

  // ---------------------------------------------------------------- chest
  'inclinePushUp': DemoSpec(DemoView.side, [
    sidePose(torso: 205, thigh: 15, shin: 15, upper: 80, fore: 80),
    sidePose(torso: 198, thigh: 12, shin: 12, upper: 30, fore: 130),
  ], prop: 'bench'),
  'declinePushUp': DemoSpec(DemoView.side, [
    sidePose(torso: 170, thigh: 350, shin: 350, upper: 90, fore: 90),
    sidePose(torso: 166, thigh: 348, shin: 348, upper: 40, fore: 135),
  ], prop: 'step'),
  'hinduPushUp': DemoSpec(DemoView.side, [
    sidePose(torso: 135, thigh: 45, shin: 45, upper: 125, fore: 125),
    sidePose(torso: 190, thigh: 6, shin: 6, upper: 50, fore: 125),
    sidePose(torso: 215, thigh: 2, shin: 2, upper: 80, fore: 85),
  ], cycle: const Duration(milliseconds: 2600)),

  // --------------------------------------------------------------- biceps
  'concentrationCurl': DemoSpec(DemoView.side, [
    sidePose(torso: 300, thigh: 0, shin: 90, upper: 80, fore: 80),
    sidePose(torso: 300, thigh: 0, shin: 90, upper: 80, fore: 255),
  ]),
  'towelCurl': DemoSpec(DemoView.side, [
    sidePose(torso: 270, thigh: 90, shin: 90, upper: 88, fore: 60),
    sidePose(torso: 270, thigh: 90, shin: 90, upper: 88, fore: 285),
  ], cycle: const Duration(milliseconds: 2400)),
  'curlHold': DemoSpec(DemoView.side, [
    sidePose(torso: 270, thigh: 90, shin: 90, upper: 90, fore: 0),
    sidePose(torso: 270, thigh: 90, shin: 90, upper: 90, fore: 358),
  ], cycle: const Duration(milliseconds: 2400)),
  'doorwayRow': DemoSpec(DemoView.side, [
    sidePose(torso: 240, thigh: 70, shin: 80, upper: 340, fore: 340),
    sidePose(torso: 256, thigh: 75, shin: 82, upper: 70, fore: 320),
  ]),

  // -------------------------------------------------------------- triceps
  'overheadExtension': DemoSpec(DemoView.front, [
    frontPose(upL: 165, foreL: 10, upR: 165, foreR: 10),
    frontPose(upL: 168, foreL: 175, upR: 168, foreR: 175),
  ]),
  'tricepKickback': DemoSpec(DemoView.side, [
    sidePose(torso: 320, thigh: 75, shin: 100, upper: 150, fore: 90),
    sidePose(torso: 320, thigh: 75, shin: 100, upper: 150, fore: 150),
  ]),
  'plankUpDown': DemoSpec(DemoView.side, [
    sidePose(torso: 190, thigh: 4, shin: 4, upper: 90, fore: 180),
    sidePose(torso: 192, thigh: 4, shin: 4, upper: 90, fore: 90),
  ], cycle: const Duration(milliseconds: 2000)),

  // ------------------------------------------------------------ shoulders
  'frontRaise': DemoSpec(DemoView.side, [
    sidePose(torso: 270, thigh: 90, shin: 90, upper: 90, fore: 90),
    sidePose(torso: 270, thigh: 90, shin: 90, upper: 0, fore: 0),
  ]),
  'pikePushUp': DemoSpec(DemoView.side, [
    sidePose(torso: 130, thigh: 50, shin: 50, upper: 130, fore: 130),
    sidePose(torso: 142, thigh: 50, shin: 50, upper: 75, fore: 160),
  ]),
  'armCircles': DemoSpec(DemoView.front, [
    frontPose(upL: 80, foreL: 80, upR: 80, foreR: 80),
    frontPose(upL: 92, foreL: 100, upR: 92, foreR: 100),
    frontPose(upL: 100, foreL: 92, upR: 100, foreR: 92),
    frontPose(upL: 88, foreL: 80, upR: 88, foreR: 80),
  ], cycle: const Duration(milliseconds: 1000)),
  'yRaise': DemoSpec(DemoView.side, [
    sidePose(torso: 182, thigh: 0, shin: 0, upper: 172, fore: 172),
    sidePose(torso: 186, thigh: 0, shin: 0, upper: 194, fore: 194),
  ]),

  // ----------------------------------------------------------------- back
  'superman': DemoSpec(DemoView.side, [
    sidePose(torso: 180, thigh: 0, shin: 0, upper: 180, fore: 180),
    sidePose(torso: 192, thigh: 350, shin: 350, upper: 195, fore: 195),
  ], cycle: const Duration(milliseconds: 2200)),
  'birdDog': DemoSpec(DemoView.side, [
    sidePose(torso: 180, thigh: 90, shin: 0, upper: 90, fore: 90),
    sidePose(torso: 180, thigh: 0, shin: 0, upper: 180, fore: 180, thighF: 90, shinF: 0, upperF: 90, foreF: 90),
  ], cycle: const Duration(milliseconds: 2200)),
  'snowAngel': DemoSpec(DemoView.side, [
    sidePose(torso: 185, thigh: 0, shin: 0, upper: 350, fore: 350),
    sidePose(torso: 185, thigh: 0, shin: 0, upper: 190, fore: 190),
  ], cycle: const Duration(milliseconds: 2200)),
  'catCow': DemoSpec(DemoView.side, [
    sidePose(torso: 176, thigh: 90, shin: 0, upper: 92, fore: 92),
    sidePose(torso: 187, thigh: 90, shin: 0, upper: 86, fore: 86),
  ], cycle: const Duration(milliseconds: 3200)),
  'cobra': DemoSpec(DemoView.side, [
    sidePose(torso: 200, thigh: 2, shin: 2, upper: 100, fore: 100),
    sidePose(torso: 213, thigh: 2, shin: 2, upper: 78, fore: 78),
  ], cycle: const Duration(milliseconds: 3200)),
  'childPose': DemoSpec(DemoView.side, [
    sidePose(torso: 178, thigh: 125, shin: 0, upper: 180, fore: 180),
    sidePose(torso: 181, thigh: 125, shin: 0, upper: 182, fore: 182),
  ], cycle: const Duration(milliseconds: 3200)),

  // ----------------------------------------------------------------- legs
  'jumpSquat': DemoSpec(DemoView.front, [
    frontPose(crouch: 1, upL: 80, foreL: 90, upR: 80, foreR: 90, hop: 0),
    frontPose(upL: 25, foreL: 25, upR: 25, foreR: 25, hop: 10),
  ], cycle: const Duration(milliseconds: 1200)),
  'sumoSquat': DemoSpec(DemoView.front, [
    frontPose(spread: 1, upL: 40, foreL: 75, upR: 40, foreR: 75),
    frontPose(spread: 1, crouch: 1.1, upL: 50, foreL: 85, upR: 50, foreR: 85),
  ]),
  'sideLunge': DemoSpec(DemoView.front, [
    frontPose(spread: 1.4, crouch: 0.15, upL: 30, foreL: 60, upR: 30, foreR: 60),
    frontPose(spread: 1.4, crouch: 0.85, upL: 45, foreL: 80, upR: 45, foreR: 80),
  ]),
  'calfRaise': DemoSpec(DemoView.front, [
    frontPose(hop: 0),
    frontPose(hop: 3.5),
  ], cycle: const Duration(milliseconds: 1500)),
  'singleLegBridge': DemoSpec(DemoView.side, [
    sidePose(torso: 180, thigh: 315, shin: 55, thighF: 335, shinF: 335, upper: 0, fore: 0),
    sidePose(torso: 163, thigh: 348, shin: 80, thighF: 342, shinF: 342, upper: 28, fore: 0),
  ]),

  // --------------------------------------------------------------- glutes
  'donkeyKick': DemoSpec(DemoView.side, [
    sidePose(torso: 180, thigh: 90, shin: 0, upper: 90, fore: 90),
    sidePose(torso: 180, thigh: 345, shin: 270, thighF: 90, shinF: 0, upper: 90, fore: 90),
  ]),
  'gluteKickback': DemoSpec(DemoView.side, [
    sidePose(torso: 180, thigh: 90, shin: 0, upper: 90, fore: 90),
    sidePose(torso: 180, thigh: 345, shin: 345, thighF: 90, shinF: 0, upper: 90, fore: 90),
  ]),

  // ----------------------------------------------------------- full body
  'buttKicks': DemoSpec(DemoView.side, [
    sidePose(torso: 274, thigh: 95, shin: 215, thighF: 90, shinF: 90, upper: 60, fore: 330, upperF: 120, foreF: 200),
    sidePose(torso: 274, thigh: 90, shin: 90, thighF: 95, shinF: 215, upper: 120, fore: 200, upperF: 60, foreF: 330),
  ], cycle: const Duration(milliseconds: 700)),
  'skater': DemoSpec(DemoView.front, [
    frontPose(crouch: 0.4, liftR: 0.5, upL: 40, foreL: 60, upR: 25, foreR: 30),
    frontPose(crouch: 0.4, liftL: 0.5, upR: 40, foreR: 60, upL: 25, foreL: 30),
  ], cycle: const Duration(milliseconds: 1100)),
  'inchworm': DemoSpec(DemoView.side, [
    sidePose(torso: 270, thigh: 90, shin: 90, upper: 90, fore: 90),
    sidePose(torso: 50, thigh: 90, shin: 90, upper: 120, fore: 150),
    sidePose(torso: 350, thigh: 175, shin: 175, upper: 90, fore: 90),
    sidePose(torso: 50, thigh: 90, shin: 90, upper: 120, fore: 150),
  ], cycle: const Duration(milliseconds: 3600)),
  'punches': DemoSpec(DemoView.side, [
    sidePose(torso: 272, thigh: 80, shin: 95, upper: 0, fore: 0, upperF: 70, foreF: 290),
    sidePose(torso: 272, thigh: 80, shin: 95, upper: 70, fore: 290, upperF: 0, foreF: 0),
  ], cycle: const Duration(milliseconds: 700)),
  'march': DemoSpec(DemoView.front, [
    frontPose(liftL: 0.6, upL: 25, foreL: 120, upR: 15, foreR: 15),
    frontPose(liftR: 0.6, upR: 25, foreR: 120, upL: 15, foreL: 15),
  ], cycle: const Duration(milliseconds: 1200)),

  // -------------------------------------------------------------- stretch
  'hamstringStretch': DemoSpec(DemoView.side, [
    sidePose(torso: 300, thigh: 0, shin: 0, upper: 40, fore: 30),
    sidePose(torso: 325, thigh: 0, shin: 0, upper: 15, fore: 5),
  ], cycle: const Duration(milliseconds: 3200)),
  'quadStretch': DemoSpec(DemoView.side, [
    sidePose(torso: 270, thigh: 95, shin: 235, thighF: 90, shinF: 90, upper: 115, fore: 80, upperF: 90, foreF: 90),
    sidePose(torso: 271, thigh: 96, shin: 236, thighF: 90, shinF: 90, upper: 116, fore: 81, upperF: 90, foreF: 90),
  ], cycle: const Duration(milliseconds: 2400)),
  'toeTouch': DemoSpec(DemoView.side, [
    sidePose(torso: 270, thigh: 90, shin: 90, upper: 270, fore: 270),
    sidePose(torso: 50, thigh: 90, shin: 90, upper: 120, fore: 150),
  ], cycle: const Duration(milliseconds: 2600)),
  'lungeStretch': DemoSpec(DemoView.side, [
    sidePose(torso: 270, thigh: 5, shin: 90, thighF: 115, shinF: 178, upper: 90, fore: 90),
    sidePose(torso: 272, thigh: 8, shin: 92, thighF: 118, shinF: 178, upper: 90, fore: 90),
  ], cycle: const Duration(milliseconds: 2600)),
};
