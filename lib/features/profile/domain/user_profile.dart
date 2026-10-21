import 'package:flutter/material.dart';

enum Gender { male, female, other }

enum FitnessGoal { loseWeight, maintain, buildMuscle }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum DietType { veg, nonVeg, eggetarian, vegan }

enum FitnessLevel { beginner, moderate, advanced }

class UserProfile {
  const UserProfile({
    required this.name,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.activity,
    required this.diet,
    required this.level,
    required this.wakeTime,
    required this.sleepTime,
  });

  final String name;
  final Gender gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final FitnessGoal goal;
  final ActivityLevel activity;
  final DietType diet;
  final FitnessLevel level;
  final TimeOfDay wakeTime;
  final TimeOfDay sleepTime;

  UserProfile copyWith({
    String? name,
    Gender? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    FitnessGoal? goal,
    ActivityLevel? activity,
    DietType? diet,
    FitnessLevel? level,
    TimeOfDay? wakeTime,
    TimeOfDay? sleepTime,
  }) => UserProfile(
    name: name ?? this.name,
    gender: gender ?? this.gender,
    age: age ?? this.age,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    goal: goal ?? this.goal,
    activity: activity ?? this.activity,
    diet: diet ?? this.diet,
    level: level ?? this.level,
    wakeTime: wakeTime ?? this.wakeTime,
    sleepTime: sleepTime ?? this.sleepTime,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender.name,
    'age': age,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'goal': goal.name,
    'activity': activity.name,
    'diet': diet.name,
    'level': level.name,
    'wake': _minutes(wakeTime),
    'sleep': _minutes(sleepTime),
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: j['name'] as String,
    gender: Gender.values.byName(j['gender'] as String),
    age: j['age'] as int,
    heightCm: (j['heightCm'] as num).toDouble(),
    weightKg: (j['weightKg'] as num).toDouble(),
    goal: FitnessGoal.values.byName(j['goal'] as String),
    activity: ActivityLevel.values.byName(j['activity'] as String),
    diet: DietType.values.byName(j['diet'] as String),
    level: FitnessLevel.values.byName(j['level'] as String),
    wakeTime: _time(j['wake'] as int),
    sleepTime: _time(j['sleep'] as int),
  );

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;
  static TimeOfDay _time(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);
}
