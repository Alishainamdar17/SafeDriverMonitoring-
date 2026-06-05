  // lib/services/database_service.dart
  import 'package:flutter/foundation.dart';
  import 'package:sqflite/sqflite.dart';
  import 'package:path/path.dart';
  import 'package:safe_drive_monitor/models/driving_record.dart';
  import 'package:safe_drive_monitor/models/drive.dart';
  import 'package:safe_drive_monitor/config/app_config.dart';
  import 'package:safe_drive_monitor/services/learning_service.dart';

  class DatabaseService {
    static Database? _database;

    final _recordBuffer = <DrivingRecord>[];
    DateTime _lastSampleTime = DateTime.now();
    int? _currentDriveId;
    DateTime? _driveStartTime;
    DateTime _lastSpeedCheck = DateTime.now();
    bool _isDriving = false;

    // ================= DATABASE INIT =================

    Future<Database> get database async {
      if (_database != null) return _database!;
      _database = await _initDB();
      return _database!;
    }

    Future<Database> _initDB() async {
      String path = join(await getDatabasesPath(), AppConfig.dbName);

      return await openDatabase(
        path,
        version: 2,
        onUpgrade: _onUpgrade,
        onCreate: (db, version) async {
          await _createTables(db);
        },
      );
    }

    Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
      if (oldVersion < 2) {
        await db.execute('DROP TABLE IF EXISTS ${AppConfig.recordsTable}');
        await db.execute('DROP TABLE IF EXISTS ${AppConfig.drivesTable}');
        await _createTables(db);
      }
    }

    Future<void> _createTables(Database db) async {
      await db.execute('''
        CREATE TABLE ${AppConfig.drivesTable}(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          start_time INTEGER NOT NULL,
          end_time INTEGER,
          duration_seconds INTEGER NOT NULL,
          average_speed REAL NOT NULL,
          over_speed_duration INTEGER NOT NULL,
          sudden_acc_groups TEXT NOT NULL,
          sudden_brake_groups TEXT NOT NULL,
          sharp_turn_groups TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE ${AppConfig.recordsTable}(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          drive_id INTEGER,
          timestamp INTEGER NOT NULL,
          speed REAL NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          accelerationX REAL NOT NULL,
          accelerationY REAL NOT NULL,
          accelerationZ REAL NOT NULL,
          totalAcceleration REAL NOT NULL,
          isSuddenAcceleration INTEGER NOT NULL,
          isSuddenBraking INTEGER NOT NULL,
          isSharpTurn INTEGER NOT NULL,
          FOREIGN KEY (drive_id) REFERENCES ${AppConfig.drivesTable}(id)
        )
      ''');

      await db.execute(
          'CREATE INDEX idx_timestamp ON ${AppConfig.recordsTable}(timestamp)');
      await db.execute(
          'CREATE INDEX idx_drive_id ON ${AppConfig.recordsTable}(drive_id)');
    }

    // ================= DRIVE LOGIC =================

    bool shouldSample(double speedKmh) {
      if (speedKmh < AppConfig.minRecordingSpeed) return false;

      final now = DateTime.now();

      Duration requiredInterval = AppConfig.speedSamplingRates.entries
          .firstWhere(
            (entry) => speedKmh < entry.key,
            orElse: () => AppConfig.speedSamplingRates.entries.last,
          )
          .value;

      if (now.difference(_lastSampleTime) >= requiredInterval) {
        _lastSampleTime = now;
        _checkDriveStatus(speedKmh, now);
        return true;
      }
      return false;
    }

    void _checkDriveStatus(double speedKmh, DateTime now) async {
      if (!_isDriving && speedKmh >= AppConfig.driveStartSpeed) {
        if (_driveStartTime == null) {
          _driveStartTime = now;
        } else if (now.difference(_driveStartTime!).inSeconds >=
            AppConfig.driveStartDuration) {
          _isDriving = true;
          _currentDriveId = await _startNewDrive(_driveStartTime!);
        }
      } else if (_isDriving && speedKmh < AppConfig.driveEndSpeed) {
        if (now.difference(_lastSpeedCheck).inSeconds >=
            AppConfig.driveEndDuration) {
          await _endCurrentDrive(now);
          _isDriving = false;
          _currentDriveId = null;
          _driveStartTime = null;
        }
      } else {
        _lastSpeedCheck = now;
      }
    }

    Future<int> _startNewDrive(DateTime startTime) async {
      final db = await database;

      return await db.insert(
        AppConfig.drivesTable,
        Drive(
          startTime: startTime,
          durationSeconds: 0,
          averageSpeed: 0,
          overSpeedDurationSeconds: 0,
          suddenAccelerations: {},
          suddenBrakings: {},
          sharpTurns: {},
        ).toMap(),
      );
    }

    Future<void> _endCurrentDrive(DateTime endTime) async {
      if (_currentDriveId == null) return;

      // FIX 1: Flush buffered records before reading them for stats
      await _flushRecordBuffer();

      final db = await database;

      final records = await db.query(
        AppConfig.recordsTable,
        where: 'drive_id = ?',
        whereArgs: [_currentDriveId],
      );

      if (records.isEmpty) return;

      final speeds = records.map((r) => (r['speed'] as num).toDouble()).toList();
      final avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;

      final durationSeconds = endTime
          .difference(DateTime.fromMillisecondsSinceEpoch(
              records.first['timestamp'] as int))
          .inSeconds;

      await db.update(
        AppConfig.drivesTable,
        {
          'end_time':         endTime.millisecondsSinceEpoch,
          'duration_seconds': durationSeconds,
          'average_speed':    avgSpeed,
        },
        where: 'id = ?',
        whereArgs: [_currentDriveId],
      );

      if (AppConfig.adaptiveLearningEnabled) {
        final driveRows = await db.query(
          AppConfig.drivesTable,
          where: 'id = ?',
          whereArgs: [_currentDriveId],
        );

        if (driveRows.isNotEmpty) {
          final drive = Drive.fromMap(driveRows.first);
          await LearningService.updateProfileFromDrive(drive);
        }
      }
    }

    // ================= INSERT RECORD =================

    // FIX 2: Removed stray literal '\n' characters from the original method
    // signature at Ln 201 that caused parse errors (missing_identifier,
    // expected_token, undefined_name 'n').
    Future<void> insertRecord(DrivingRecord record) async {
      if (_currentDriveId == null) return;

      final recordWithDrive = DrivingRecord(
        driveId: _currentDriveId,
        timestamp: record.timestamp,
        speed: record.speed,
        latitude: record.latitude,
        longitude: record.longitude,
        accelerationX: record.accelerationX,
        accelerationY: record.accelerationY,
        accelerationZ: record.accelerationZ,
        totalAcceleration: record.totalAcceleration,
        isSuddenAcceleration: record.isSuddenAcceleration,
        isSuddenBraking: record.isSuddenBraking,
        isSharpTurn: record.isSharpTurn,
      );

      _recordBuffer.add(recordWithDrive);

      if (_recordBuffer.length >= AppConfig.batchSize) {
        await _flushRecordBuffer();
      }
    }

    // FIX 1: Added the missing _flushRecordBuffer() method.
    // It was called at Ln 154 in _endCurrentDrive() but never defined,
    // causing "The method '_flushRecordBuffer' isn't defined" error.
    // Also reused inside insertRecord() to avoid duplicated batch logic.
    Future<void> _flushRecordBuffer() async {
      if (_recordBuffer.isEmpty) return;

      final db = await database;

      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var r in _recordBuffer) {
          batch.insert(AppConfig.recordsTable, r.toMap());
        }
        await batch.commit();
      });

      _recordBuffer.clear();
      await _cleanOldRecords();
    }

    // ================= CLEANUP =================

    Future<void> _cleanOldRecords() async {
      final db = await database;

      final cutoffDate =
          DateTime.now().subtract(Duration(days: AppConfig.retentionDays));

      await db.delete(
        AppConfig.recordsTable,
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.millisecondsSinceEpoch],
      );

      await db.delete(
        AppConfig.drivesTable,
        where: 'start_time < ?',
        whereArgs: [cutoffDate.millisecondsSinceEpoch],
      );
    }

    // ================= FETCH DATA =================

    Future<List<Drive>> getDrives() async {
      try {
        final db = await database;

        final driveRows = await db.query(
          AppConfig.drivesTable,
          orderBy: 'start_time DESC',
        );

        return driveRows.map((row) => Drive.fromMap(row)).toList();
      } catch (e) {
        debugPrint('DB ERROR: $e');
        return [];
      }
    }

    // ================= DEBUG =================

    Future<void> debugDatabase() async {
      final db = await database;

      final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM ${AppConfig.drivesTable}'));

      debugPrint('Total Drives: $count');
    }
  }