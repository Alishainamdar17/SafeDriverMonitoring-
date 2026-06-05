import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_drive_monitor/models/drive.dart';
import 'package:safe_drive_monitor/models/driver_profile.dart';

class LearningService {
  static const _profileKey = 'driver_profile';

  static Future<DriverProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonText = prefs.getString(_profileKey);
    if (jsonText == null) {
      return DriverProfile.defaultProfile();
    }
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    return DriverProfile.fromJson(decoded);
  }

  static Future<void> saveProfile(DriverProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  static Future<DriverProfile> updateProfileFromDrive(Drive drive) async {
    final previousProfile = await loadProfile();
    final newProfile = _profileFromDrive(drive);
    final mergedProfile = previousProfile.mergeWith(newProfile);
    await saveProfile(mergedProfile);
    return mergedProfile;
  }

  static DriverProfile _profileFromDrive(Drive drive) {
    final totalEvents = drive.suddenAccelerations.values.fold<int>(0, (sum, value) => sum + value) +
        drive.suddenBrakings.values.fold<int>(0, (sum, value) => sum + value) +
        drive.sharpTurns.values.fold<int>(0, (sum, value) => sum + value);

    final eventRate = drive.durationSeconds > 0
        ? totalEvents / drive.durationSeconds
        : 0.0;

    final overSpeedRatio = drive.durationSeconds > 0
        ? drive.overSpeedDurationSeconds / drive.durationSeconds
        : 0.0;

    return DriverProfile(
      averageSpeed: drive.averageSpeed,
      averageOverSpeedRatio: overSpeedRatio,
      averageEventRate: eventRate,
      driveCount: 1,
    );
  }
}
