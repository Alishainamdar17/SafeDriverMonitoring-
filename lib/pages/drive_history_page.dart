// lib/pages/drive_history_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safe_drive_monitor/services/live_drive_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriveHistoryPage extends StatefulWidget {
  const DriveHistoryPage({super.key});
  @override
  State<DriveHistoryPage> createState() => _DriveHistoryPageState();
}

class _DriveHistoryPageState extends State<DriveHistoryPage>
    with TickerProviderStateMixin {

  late AnimationController _entryController;
  late Animation<double> _entryAnim;
  final LiveDriveState _state = LiveDriveState.instance;

  List<Map<String, dynamic>> _firebaseHistory = [];
  bool _loading = true;

  // ✅ FIXED: same collection as live_drive_state.dart
  static const String _kCollection = 'live_drives';

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _entryAnim =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _state.addListener(_onStateUpdate);
    _loadFirebaseHistory();
  }

  Future<void> _loadFirebaseHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      // ✅ FIXED: correct collection + userId filter
      final snap = await FirebaseFirestore.instance
          .collection(_kCollection)
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('startTime', descending: true)
          .limit(50)
          .get();

      debugPrint('✅ DriveHistory: ${snap.docs.length} docs found');

      setState(() {
        _firebaseHistory = snap.docs.map((d) {
          final data = d.data();
          data['docId'] = d.id;
          return data;
        }).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Firebase history load error: $e');
      setState(() => _loading = false);
    }
  }

  void _onStateUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entryController.dispose();
    _state.removeListener(_onStateUpdate);
    super.dispose();
  }

  String _fmtDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _fmtDist(double km) =>
      km >= 1 ? '${km.toStringAsFixed(1)} km' : '${(km * 1000).toStringAsFixed(0)} m';

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  String _fmt24(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Color _scoreColor(double s) {
    if (s >= 80) return const Color(0xFF34C759);
    if (s >= 55) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF2D55);
  }

  String _grade(double s) {
    if (s >= 90) return 'A+';
    if (s >= 80) return 'A';
    if (s >= 70) return 'B';
    if (s >= 55) return 'C';
    return 'D';
  }

  // ✅ FIXED: safe int cast — handles both int and double from Firestore
  int _safeInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }

  int _foldEventMap(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is Map) {
      return raw.values.fold<int>(0, (s, v) => s + _safeInt(v));
    }
    return 0;
  }

  double _calcScore(Map<String, dynamic> doc) {
    // ✅ FIXED: use safetyScore from Firestore if present
    final saved = (doc['safetyScore'] as num?)?.toDouble() ?? 0;
    if (saved > 0) return saved;

    // Fallback: recalculate
    final brakes     = _foldEventMap(doc['suddenBrakings']);
    final accels     = _foldEventMap(doc['suddenAccelerations']);
    final turns      = _foldEventMap(doc['sharpTurns']);
    final overspeeds = _safeInt(doc['overSpeedDurationSeconds']) ~/ 30;
    double score = 100;
    score -= brakes * 5;
    score -= accels * 3;
    score -= turns * 4;
    score -= overspeeds * 5;
    return score.clamp(0.0, 100.0);
  }

  // ✅ FIXED: use distanceKm field first, fallback to speed*time calc
  double _calcDist(Map<String, dynamic> doc) {
    final saved = (doc['distanceKm'] as num?)?.toDouble() ?? 0;
    if (saved > 0) return saved;
    final speed = (doc['averageSpeed'] as num?)?.toDouble() ?? 0;
    final secs  = (doc['durationSeconds'] as num?)?.toDouble() ?? 0;
    return (speed * secs) / 3600;
  }

  @override
  Widget build(BuildContext context) {
    final current   = _state.current;
    final totalTrips = _firebaseHistory.length + _state.history.length;

    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: FadeTransition(
        opacity: _entryAnim,
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(totalTrips + (current != null ? 1 : 0)),
              _buildSummaryStrip(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF00D4FF)))
                    : (_firebaseHistory.isEmpty &&
                            _state.history.isEmpty &&
                            current == null)
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadFirebaseHistory,
                            color: const Color(0xFF00D4FF),
                            child: ListView(
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              children: [
                                if (current != null)
                                  _buildCurrentSessionCard(current),
                                ..._state.history.map(
                                    (s) => _buildMemoryCard(s)),
                                if (_firebaseHistory.isNotEmpty) ...[
                                  if (_state.history.isNotEmpty)
                                    _buildDividerLabel('PREVIOUS TRIPS'),
                                  ..._firebaseHistory.map(
                                      (doc) => _buildFirebaseCard(doc)),
                                ],
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDividerLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        const Expanded(child: Divider(color: Color(0xFF1C1C2E))),
        const SizedBox(width: 10),
        Text(text,
            style: const TextStyle(
                color: Color(0xFF636366),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: Color(0xFF1C1C2E))),
      ]),
    );
  }

  Widget _buildTopBar(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF050508),
        border:
            Border(bottom: BorderSide(color: Color(0xFF1C1C2E), width: 1)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1C1C2E), width: 1),
            ),
            child: const Icon(Icons.arrow_back_ios_rounded,
                color: Color(0xFF8E8E93), size: 16),
          ),
        ),
        const SizedBox(width: 14),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DRIVE HISTORY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                fontFamily: 'monospace',
              )),
          Text('Firebase + Live sessions',
              style: TextStyle(color: Color(0xFF636366), fontSize: 11)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: _loadFirebaseHistory,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF00D4FF).withOpacity(0.3), width: 1),
            ),
            child: Row(children: [
              const Icon(Icons.refresh_rounded,
                  color: Color(0xFF00D4FF), size: 14),
              const SizedBox(width: 5),
              Text('$count TRIPS',
                  style: const TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  )),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildSummaryStrip() {
    double fbDistance = 0;
    int fbSeconds     = 0;
    double fbScoreSum = 0;

    for (final doc in _firebaseHistory) {
      fbDistance += _calcDist(doc);
      fbSeconds  += _safeInt(doc['durationSeconds']);
      fbScoreSum += _calcScore(doc);
    }

    final totalDistKm = _state.totalDistanceKm + fbDistance;
    final totalSecs   = _state.totalDriveTime.inSeconds + fbSeconds;
    final totalTrips  = _state.totalTrips + _firebaseHistory.length;
    final avgScore    = totalTrips > 0
        ? ((_state.allTimeAvgScore * _state.totalTrips) + fbScoreSum) /
            totalTrips
        : 0.0;

    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF00D4FF).withOpacity(0.08),
          const Color(0xFF0066FF).withOpacity(0.04),
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF00D4FF).withOpacity(0.15), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryStat('${totalDistKm.toStringAsFixed(1)} km', 'Distance',
              Icons.route_rounded, const Color(0xFF00D4FF)),
          _divider(),
          _summaryStat('${h}h ${m}m', 'Drive Time', Icons.timer_rounded,
              const Color(0xFF5E5CE6)),
          _divider(),
          _summaryStat(
              avgScore > 0 ? avgScore.toStringAsFixed(0) : '--',
              'Avg Score',
              Icons.shield_rounded,
              avgScore >= 80
                  ? const Color(0xFF34C759)
                  : avgScore >= 55
                      ? const Color(0xFFFF9F0A)
                      : avgScore > 0
                          ? const Color(0xFFFF2D55)
                          : const Color(0xFF636366)),
          _divider(),
          _summaryStat('$totalTrips', 'Trips',
              Icons.directions_car_rounded, const Color(0xFF34C759)),
        ],
      ),
    );
  }

  Widget _summaryStat(
      String value, String label, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 5),
      Text(value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          )),
      Text(label,
          style: const TextStyle(color: Color(0xFF636366), fontSize: 9)),
    ]);
  }

  Widget _divider() =>
      Container(width: 1, height: 36, color: const Color(0xFF1C1C2E));

  // ── FIREBASE CARD ──────────────────────────────────────────────────────────
  Widget _buildFirebaseCard(Map<String, dynamic> doc) {
    final score    = _calcScore(doc);
    final distKm   = _calcDist(doc);
    final color    = _scoreColor(score);
    final gradeStr = _grade(score);

    DateTime? startTime;
    try {
      final ts = doc['startTime'];
      if (ts is Timestamp) startTime = ts.toDate();
      else if (ts is String) startTime = DateTime.tryParse(ts);
    } catch (_) {}

    final durationSec = _safeInt(doc['durationSeconds']);
    final avgSpeed    = (doc['averageSpeed'] as num?)?.toDouble() ?? 0;
    final brakes      = _foldEventMap(doc['suddenBrakings']);
    final overspeeds  = _safeInt(doc['overSpeedDurationSeconds']) ~/ 30;

    return GestureDetector(
      onTap: () => _showFirebaseDetail(doc, score, gradeStr),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(children: [
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: Text(gradeStr,
                    style: TextStyle(
                      color: color, fontSize: 16, fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    )),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (doc['startLocation'] as String?)?.isNotEmpty == true
                          ? doc['startLocation'] as String
                          : 'Drive Trip',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      startTime != null
                          ? '${_timeAgo(startTime)} · ${_fmt24(startTime)}'
                          : 'Unknown time',
                      style: const TextStyle(
                          color: Color(0xFF636366), fontSize: 11),
                    ),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${score.toInt()}',
                  style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  )),
              const Text('/100',
                  style: TextStyle(color: Color(0xFF636366), fontSize: 9)),
            ]),
          ]),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFF1C1C2E)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _miniStat(Icons.route_rounded, _fmtDist(distKm),
                const Color(0xFF00D4FF)),
            _miniStat(Icons.timer_rounded, _fmtDuration(durationSec),
                const Color(0xFF5E5CE6)),
            _miniStat(Icons.speed_rounded,
                '${avgSpeed.toStringAsFixed(0)} km/h',
                const Color(0xFF34C759)),
            _miniStat(Icons.front_hand_rounded, '$brakes Brakes',
                const Color(0xFFFF9F0A)),
          ]),
          if (brakes > 0 || overspeeds > 0) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (brakes > 0)
                _eventBadge('$brakes Brakes', const Color(0xFFFF9F0A)),
              if (overspeeds > 0) ...[
                const SizedBox(width: 6),
                _eventBadge('${overspeeds}× Over', const Color(0xFFFF2D55)),
              ],
            ]),
          ],
        ]),
      ),
    );
  }

  void _showFirebaseDetail(
      Map<String, dynamic> doc, double score, String gradeStr) {
    final color       = _scoreColor(score);
    final durationSec = _safeInt(doc['durationSeconds']);
    final distKm      = _calcDist(doc);
    final avgSpeed    = (doc['averageSpeed'] as num?)?.toDouble() ?? 0;
    final brakes      = _foldEventMap(doc['suddenBrakings']);
    final accels      = _foldEventMap(doc['suddenAccelerations']);
    final turns       = _foldEventMap(doc['sharpTurns']);
    final overspeeds  = _safeInt(doc['overSpeedDurationSeconds']) ~/ 30;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C14),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.cloud_done_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              const Text('TRIP DETAIL',
                  style: TextStyle(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ]),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.1),
                  border: Border.all(color: color, width: 2.5),
                ),
                child: Center(
                    child: Text(gradeStr,
                        style: TextStyle(
                            color: color, fontSize: 26,
                            fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 20),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${score.toInt()}/100',
                    style: TextStyle(
                        color: color, fontSize: 30,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace')),
                Text('Safety Score',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 18),
            _detailRow('Duration', _fmtDuration(durationSec),
                Icons.timer_rounded, const Color(0xFF5E5CE6)),
            const SizedBox(height: 8),
            _detailRow('Distance', _fmtDist(distKm),
                Icons.route_rounded, const Color(0xFF00D4FF)),
            const SizedBox(height: 8),
            _detailRow('Avg Speed', '${avgSpeed.toStringAsFixed(1)} km/h',
                Icons.speed_rounded, const Color(0xFF34C759)),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('EVENTS',
                  style: TextStyle(
                      color: Color(0xFF636366), fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _eventTile('Brakes', brakes, Icons.front_hand_rounded,
                  const Color(0xFFFF9F0A)),
              const SizedBox(width: 8),
              _eventTile('Accels', accels, Icons.arrow_upward_rounded,
                  const Color(0xFFFF2D55)),
              const SizedBox(width: 8),
              _eventTile('Turns', turns, Icons.turn_right_rounded,
                  const Color(0xFF5E5CE6)),
              const SizedBox(width: 8),
              _eventTile('Overspeeds', overspeeds, Icons.speed_rounded,
                  const Color(0xFFFF2D55)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close',
                    style: TextStyle(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── LIVE SESSION CARD ──────────────────────────────────────────────────────
  Widget _buildCurrentSessionCard(LiveDriveSession session) {
    return GestureDetector(
      onTap: () => _showMemoryDetail(session, isCurrent: true),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF34C759).withOpacity(0.5), width: 1.5),
        ),
        child: Column(children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34C759), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('LIVE NOW',
                    style: TextStyle(
                      color: Color(0xFF34C759), fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1,
                    )),
              ]),
            ),
            const Spacer(),
            Text('${session.safetyScore.toInt()}',
                style: const TextStyle(
                  color: Color(0xFF34C759), fontSize: 22,
                  fontWeight: FontWeight.w900, fontFamily: 'monospace',
                )),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _miniStat(Icons.route_rounded,
                _fmtDist(session.distanceKm), const Color(0xFF00D4FF)),
            _miniStat(Icons.timer_rounded,
                _fmtDurationSec(session.duration.inSeconds),
                const Color(0xFF5E5CE6)),
            _miniStat(Icons.speed_rounded,
                '${session.avgSpeed.toStringAsFixed(0)} km/h',
                const Color(0xFF34C759)),
            _miniStat(Icons.flash_on_rounded,
                '${session.maxSpeed.toStringAsFixed(0)} km/h',
                const Color(0xFFFF9F0A)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildMemoryCard(LiveDriveSession session) {
    final color = _scoreColor(session.safetyScore);
    return GestureDetector(
      onTap: () => _showMemoryDetail(session, isCurrent: false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(children: [
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                  child: Text(session.grade,
                      style: TextStyle(
                          color: color, fontSize: 16,
                          fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.startLocation.isNotEmpty
                          ? session.startLocation
                          : 'Recent Trip',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(_timeAgo(session.startTime),
                        style: const TextStyle(
                            color: Color(0xFF636366), fontSize: 11)),
                  ]),
            ),
            Text('${session.safetyScore.toInt()}',
                style: TextStyle(
                    color: color, fontSize: 22,
                    fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          ]),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFF1C1C2E)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _miniStat(Icons.route_rounded, _fmtDist(session.distanceKm),
                const Color(0xFF00D4FF)),
            _miniStat(Icons.timer_rounded,
                _fmtDurationSec(session.duration.inSeconds),
                const Color(0xFF5E5CE6)),
            _miniStat(Icons.speed_rounded,
                '${session.maxSpeed.toStringAsFixed(0)} km/h',
                const Color(0xFFFF9F0A)),
            _miniStat(Icons.trending_flat_rounded,
                '${session.avgSpeed.toStringAsFixed(0)} km/h',
                const Color(0xFF34C759)),
          ]),
        ]),
      ),
    );
  }

  void _showMemoryDetail(LiveDriveSession session, {required bool isCurrent}) {
    final color = isCurrent
        ? const Color(0xFF34C759)
        : _scoreColor(session.safetyScore);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C14),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Icon(
                  isCurrent
                      ? Icons.radio_button_checked
                      : Icons.summarize_rounded,
                  color: color, size: 18),
              const SizedBox(width: 8),
              Text(isCurrent ? 'LIVE TRIP' : 'TRIP DETAIL',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ]),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.1),
                  border: Border.all(color: color, width: 2.5),
                ),
                child: Center(
                    child: Text(isCurrent ? 'LIVE' : session.grade,
                        style: TextStyle(
                            color: color,
                            fontSize: isCurrent ? 14 : 26,
                            fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 20),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${session.safetyScore.toInt()}/100',
                    style: TextStyle(
                        color: color, fontSize: 30,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace')),
                Text('Safety Score',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 18),
            _detailRow('Duration',
                _fmtDurationSec(session.duration.inSeconds),
                Icons.timer_rounded, const Color(0xFF5E5CE6)),
            const SizedBox(height: 8),
            _detailRow('Distance', _fmtDist(session.distanceKm),
                Icons.route_rounded, const Color(0xFF00D4FF)),
            const SizedBox(height: 8),
            _detailRow('Max Speed',
                '${session.maxSpeed.toStringAsFixed(1)} km/h',
                Icons.flash_on_rounded, const Color(0xFFFF2D55)),
            const SizedBox(height: 8),
            _detailRow('Avg Speed',
                '${session.avgSpeed.toStringAsFixed(1)} km/h',
                Icons.trending_flat_rounded, const Color(0xFF34C759)),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('EVENTS',
                  style: TextStyle(
                      color: Color(0xFF636366), fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _eventTile('Brakes', session.hardBrakeCount,
                  Icons.front_hand_rounded, const Color(0xFFFF9F0A)),
              const SizedBox(width: 8),
              _eventTile('Accels', session.hardAccelCount,
                  Icons.arrow_upward_rounded, const Color(0xFFFF2D55)),
              const SizedBox(width: 8),
              _eventTile('Turns', session.sharpTurnCount,
                  Icons.turn_right_rounded, const Color(0xFF5E5CE6)),
              const SizedBox(width: 8),
              _eventTile('Overspeeds', session.overSpeedCount,
                  Icons.speed_rounded, const Color(0xFFFF2D55)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close',
                    style: TextStyle(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  String _fmtDurationSec(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Widget _miniStat(IconData icon, String value, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(
            color: Colors.white, fontSize: 11,
            fontWeight: FontWeight.w700, fontFamily: 'monospace',
          )),
    ]);
  }

  Widget _eventBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 0.3)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.directions_car_rounded, color: Colors.grey[700], size: 48),
        const SizedBox(height: 14),
        Text('No drives yet',
            style: TextStyle(
                color: Colors.grey[600], fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Start driving to record your first trip',
            style: TextStyle(color: Colors.grey[700], fontSize: 12)),
      ]),
    );
  }

  Widget _detailRow(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w700, fontFamily: 'monospace')),
      ]),
    );
  }

  Widget _eventTile(
      String label, int count, IconData icon, Color color) {
    final has = count > 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: has ? color.withOpacity(0.08) : const Color(0xFF0F0F18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: has ? color.withOpacity(0.3) : const Color(0xFF1C1C2E),
              width: 1),
        ),
        child: Column(children: [
          Icon(icon,
              color: has ? color : const Color(0xFF3A3A4A), size: 16),
          const SizedBox(height: 4),
          Text('$count',
              style: TextStyle(
                  color: has ? color : Colors.grey[700],
                  fontSize: 18, fontWeight: FontWeight.w900,
                  fontFamily: 'monospace')),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF636366), fontSize: 8),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
