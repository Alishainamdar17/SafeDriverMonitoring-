import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────────
//  DRIVE LIST PAGE — Drive History with Default Data
// ─────────────────────────────────────────────────────────────────────────────

class DriveSession {
  final String id;
  final DateTime startTime;
  final Duration duration;
  final double distanceMeters;
  final double maxSpeed;
  final double avgSpeed;
  final double safetyScore;
  final int hardBrakes;
  final int hardAccels;
  final int sharpTurns;
  final int overSpeeds;
  final bool isNightDrive;
  final int drowsinessEvents;
  final String startLocation;
  final String endLocation;

  const DriveSession({
    required this.id,
    required this.startTime,
    required this.duration,
    required this.distanceMeters,
    required this.maxSpeed,
    required this.avgSpeed,
    required this.safetyScore,
    required this.hardBrakes,
    required this.hardAccels,
    required this.sharpTurns,
    required this.overSpeeds,
    required this.isNightDrive,
    required this.drowsinessEvents,
    required this.startLocation,
    required this.endLocation,
  });

  String get grade {
    if (safetyScore >= 90) return 'A+';
    if (safetyScore >= 80) return 'A';
    if (safetyScore >= 70) return 'B';
    if (safetyScore >= 55) return 'C';
    return 'D';
  }

  Color get scoreColor {
    if (safetyScore >= 80) return const Color(0xFF34C759);
    if (safetyScore >= 55) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF2D55);
  }
}

// ── Default / Mock Drive History Data ─────────────────────────────────────────
final List<DriveSession> _defaultDriveHistory = [
  DriveSession(
    id: 'drv_001',
    startTime: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
    duration: const Duration(hours: 0, minutes: 42, seconds: 18),
    distanceMeters: 18340,
    maxSpeed: 72.4,
    avgSpeed: 38.2,
    safetyScore: 94.0,
    hardBrakes: 0,
    hardAccels: 1,
    sharpTurns: 2,
    overSpeeds: 0,
    isNightDrive: false,
    drowsinessEvents: 0,
    startLocation: 'Shivajinagar, Pune',
    endLocation: 'Hinjewadi Phase 1, Pune',
  ),
  DriveSession(
    id: 'drv_002',
    startTime: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
    duration: const Duration(hours: 1, minutes: 12, seconds: 44),
    distanceMeters: 34870,
    maxSpeed: 98.6,
    avgSpeed: 55.3,
    safetyScore: 76.0,
    hardBrakes: 2,
    hardAccels: 3,
    sharpTurns: 1,
    overSpeeds: 4,
    isNightDrive: false,
    drowsinessEvents: 0,
    startLocation: 'Kothrud, Pune',
    endLocation: 'Lonavala Highway',
  ),
  DriveSession(
    id: 'drv_003',
    startTime: DateTime.now().subtract(const Duration(days: 1, hours: 20, minutes: 30)),
    duration: const Duration(hours: 0, minutes: 28, seconds: 5),
    distanceMeters: 9120,
    maxSpeed: 61.0,
    avgSpeed: 28.7,
    safetyScore: 88.5,
    hardBrakes: 1,
    hardAccels: 0,
    sharpTurns: 3,
    overSpeeds: 1,
    isNightDrive: true,
    drowsinessEvents: 1,
    startLocation: 'Koregaon Park, Pune',
    endLocation: 'Viman Nagar, Pune',
  ),
  DriveSession(
    id: 'drv_004',
    startTime: DateTime.now().subtract(const Duration(days: 2, hours: 7, minutes: 10)),
    duration: const Duration(hours: 2, minutes: 55, seconds: 33),
    distanceMeters: 96400,
    maxSpeed: 118.2,
    avgSpeed: 78.1,
    safetyScore: 61.0,
    hardBrakes: 5,
    hardAccels: 4,
    sharpTurns: 2,
    overSpeeds: 11,
    isNightDrive: false,
    drowsinessEvents: 2,
    startLocation: 'Pune Station',
    endLocation: 'Mumbai (Bandra)',
  ),
  DriveSession(
    id: 'drv_005',
    startTime: DateTime.now().subtract(const Duration(days: 3, hours: 9)),
    duration: const Duration(hours: 0, minutes: 19, seconds: 48),
    distanceMeters: 6200,
    maxSpeed: 54.8,
    avgSpeed: 22.4,
    safetyScore: 98.0,
    hardBrakes: 0,
    hardAccels: 0,
    sharpTurns: 0,
    overSpeeds: 0,
    isNightDrive: false,
    drowsinessEvents: 0,
    startLocation: 'Baner, Pune',
    endLocation: 'Aundh, Pune',
  ),
  DriveSession(
    id: 'drv_006',
    startTime: DateTime.now().subtract(const Duration(days: 3, hours: 22, minutes: 45)),
    duration: const Duration(hours: 1, minutes: 5, seconds: 12),
    distanceMeters: 22600,
    maxSpeed: 85.0,
    avgSpeed: 44.8,
    safetyScore: 70.5,
    hardBrakes: 3,
    hardAccels: 2,
    sharpTurns: 5,
    overSpeeds: 3,
    isNightDrive: true,
    drowsinessEvents: 3,
    startLocation: 'Wakad, Pune',
    endLocation: 'Swargate, Pune',
  ),
  DriveSession(
    id: 'drv_007',
    startTime: DateTime.now().subtract(const Duration(days: 5, hours: 6, minutes: 30)),
    duration: const Duration(hours: 3, minutes: 40, seconds: 20),
    distanceMeters: 152300,
    maxSpeed: 124.6,
    avgSpeed: 82.4,
    safetyScore: 55.0,
    hardBrakes: 7,
    hardAccels: 6,
    sharpTurns: 3,
    overSpeeds: 18,
    isNightDrive: false,
    drowsinessEvents: 4,
    startLocation: 'Pune (FC Road)',
    endLocation: 'Nashik (CBS)',
  ),
  DriveSession(
    id: 'drv_008',
    startTime: DateTime.now().subtract(const Duration(days: 6, hours: 11)),
    duration: const Duration(hours: 0, minutes: 35, seconds: 0),
    distanceMeters: 13800,
    maxSpeed: 67.3,
    avgSpeed: 31.2,
    safetyScore: 91.5,
    hardBrakes: 1,
    hardAccels: 1,
    sharpTurns: 1,
    overSpeeds: 0,
    isNightDrive: false,
    drowsinessEvents: 0,
    startLocation: 'Hadapsar, Pune',
    endLocation: 'Magarpatta City',
  ),
];

class DriveListPage extends StatefulWidget {
  const DriveListPage({super.key});

  @override
  State<DriveListPage> createState() => _DriveListPageState();
}

class _DriveListPageState extends State<DriveListPage>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _entryAnim;

  String _filterType = 'ALL'; // ALL, TODAY, WEEK, NIGHT
  List<DriveSession> get _filteredDrives {
    final now = DateTime.now();
    switch (_filterType) {
      case 'TODAY':
        return _defaultDriveHistory
            .where((d) => d.startTime.day == now.day &&
                d.startTime.month == now.month &&
                d.startTime.year == now.year)
            .toList();
      case 'WEEK':
        return _defaultDriveHistory
            .where((d) =>
                now.difference(d.startTime).inDays <= 7)
            .toList();
      case 'NIGHT':
        return _defaultDriveHistory.where((d) => d.isNightDrive).toList();
      default:
        return _defaultDriveHistory;
    }
  }

  // ── Aggregates ─────────────────────────────────────────────────────────────
  double get _totalDistanceKm =>
      _defaultDriveHistory.fold(0.0, (s, d) => s + d.distanceMeters) / 1000;

  double get _avgSafetyScore {
    if (_defaultDriveHistory.isEmpty) return 0;
    return _defaultDriveHistory.fold(0.0, (s, d) => s + d.safetyScore) /
        _defaultDriveHistory.length;
  }

  int get _totalDrives => _defaultDriveHistory.length;

  Duration get _totalDriveTime =>
      _defaultDriveHistory.fold(Duration.zero, (s, d) => s + d.duration);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..forward();
    _entryAnim = CurvedAnimation(
      parent: _entryController, curve: Curves.easeOut,
    );
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatDist(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  String _formatStartTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: FadeTransition(
        opacity: _entryAnim,
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildSummaryStrip(),
              _buildFilterTabs(),
              Expanded(
                child: _filteredDrives.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _filteredDrives.length,
                        itemBuilder: (context, index) {
                          return _buildDriveCard(
                              _filteredDrives[index], index);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  TOP BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF050508),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1C1C2E), width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C14),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFF1C1C2E), width: 1),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: Color(0xFF8E8E93), size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DRIVE HISTORY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'All recorded sessions',
                style: TextStyle(
                    color: Color(0xFF636366),
                    fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                  width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded,
                    color: Color(0xFF00D4FF), size: 14),
                const SizedBox(width: 5),
                Text(
                  '${_defaultDriveHistory.length} TRIPS',
                  style: const TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SUMMARY STRIP
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSummaryStrip() {
    final totalH = _totalDriveTime.inHours;
    final totalM = _totalDriveTime.inMinutes % 60;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D4FF).withValues(alpha: 0.08),
            const Color(0xFF0066FF).withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF00D4FF).withValues(alpha: 0.15),
            width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryStat(
              '${_totalDistanceKm.toStringAsFixed(0)} km',
              'Total Distance',
              Icons.route_rounded,
              const Color(0xFF00D4FF)),
          _summaryDivider(),
          _summaryStat(
              '${totalH}h ${totalM}m',
              'Drive Time',
              Icons.timer_rounded,
              const Color(0xFF5E5CE6)),
          _summaryDivider(),
          _summaryStat(
              '${_avgSafetyScore.toStringAsFixed(0)}',
              'Avg Score',
              Icons.shield_rounded,
              _avgSafetyScore >= 80
                  ? const Color(0xFF34C759)
                  : _avgSafetyScore >= 55
                      ? const Color(0xFFFF9F0A)
                      : const Color(0xFFFF2D55)),
          _summaryDivider(),
          _summaryStat(
              '$_totalDrives',
              'Trips',
              Icons.directions_car_rounded,
              const Color(0xFF34C759)),
        ],
      ),
    );
  }

  Widget _summaryStat(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          label,
          style: const TextStyle(
              color: Color(0xFF636366), fontSize: 9),
        ),
      ],
    );
  }

  Widget _summaryDivider() {
    return Container(
        width: 1, height: 36, color: const Color(0xFF1C1C2E));
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  FILTER TABS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFilterTabs() {
    final filters = ['ALL', 'TODAY', 'WEEK', 'NIGHT'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: filters
            .map((f) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _filterType = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: EdgeInsets.only(
                          right: f == filters.last ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _filterType == f
                            ? const Color(0xFF00D4FF).withValues(alpha: 0.15)
                            : const Color(0xFF0C0C14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _filterType == f
                              ? const Color(0xFF00D4FF)
                                  .withValues(alpha: 0.5)
                              : const Color(0xFF1C1C2E),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        f,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _filterType == f
                              ? const Color(0xFF00D4FF)
                              : const Color(0xFF636366),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  DRIVE CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDriveCard(DriveSession session, int index) {
    return GestureDetector(
      onTap: () => _showDriveDetail(session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: session.scoreColor.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: session.scoreColor.withValues(alpha: 0.05),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Row 1: Header ─────────────────────────────────────────────
            Row(
              children: [
                // Grade badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: session.scoreColor.withValues(alpha: 0.1),
                    border: Border.all(
                        color: session.scoreColor, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      session.grade,
                      style: TextStyle(
                        color: session.scoreColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${session.startLocation} → ${session.endLocation}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            _timeAgo(session.startTime),
                            style: const TextStyle(
                                color: Color(0xFF636366),
                                fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          Text('•',
                              style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 10)),
                          const SizedBox(width: 6),
                          Text(
                            _formatStartTime(session.startTime),
                            style: const TextStyle(
                                color: Color(0xFF636366),
                                fontSize: 11,
                                fontFamily: 'monospace'),
                          ),
                          if (session.isNightDrive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5E5CE6)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.nights_stay_rounded,
                                      color: Color(0xFF5E5CE6),
                                      size: 9),
                                  SizedBox(width: 2),
                                  Text('NIGHT',
                                      style: TextStyle(
                                        color: Color(0xFF5E5CE6),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${session.safetyScore.toInt()}',
                      style: TextStyle(
                        color: session.scoreColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text('/100',
                        style: TextStyle(
                            color: Colors.grey[700], fontSize: 9)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),
            Container(height: 1, color: const Color(0xFF1C1C2E)),
            const SizedBox(height: 12),

            // ── Row 2: Stats ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat(Icons.route_rounded,
                    _formatDist(session.distanceMeters),
                    const Color(0xFF00D4FF)),
                _miniStat(Icons.timer_rounded,
                    _formatDuration(session.duration),
                    const Color(0xFF5E5CE6)),
                _miniStat(Icons.speed_rounded,
                    '${session.maxSpeed.toStringAsFixed(0)} km/h',
                    const Color(0xFFFF9F0A)),
                _miniStat(Icons.trending_flat_rounded,
                    '${session.avgSpeed.toStringAsFixed(0)} km/h',
                    const Color(0xFF34C759)),
              ],
            ),

            // ── Event badges row ──────────────────────────────────────────
            if (session.hardBrakes > 0 ||
                session.overSpeeds > 0 ||
                session.drowsinessEvents > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (session.hardBrakes > 0)
                    _eventBadge(
                        '${session.hardBrakes} Hard Brakes',
                        const Color(0xFFFF9F0A)),
                  if (session.overSpeeds > 0) ...[
                    const SizedBox(width: 6),
                    _eventBadge(
                        '${session.overSpeeds}× Overspeed',
                        const Color(0xFFFF2D55)),
                  ],
                  if (session.drowsinessEvents > 0) ...[
                    const SizedBox(width: 6),
                    _eventBadge(
                        '${session.drowsinessEvents} Drowsy',
                        const Color(0xFF5E5CE6)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            )),
      ],
    );
  }

  Widget _eventBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  EMPTY STATE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_rounded,
              color: Colors.grey[700], size: 48),
          const SizedBox(height: 14),
          Text('No drives found',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Try a different filter',
              style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  DRIVE DETAIL BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────────────
  void _showDriveDetail(DriveSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DriveDetailSheet(session: session),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DRIVE DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _DriveDetailSheet extends StatelessWidget {
  final DriveSession session;

  const _DriveDetailSheet({required this.session});

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatDist(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: session.scoreColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Icon(Icons.summarize_rounded,
                    color: session.scoreColor, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'TRIP DETAIL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                if (session.isNightDrive)
                  const Icon(Icons.nights_stay_rounded,
                      color: Color(0xFF5E5CE6), size: 16),
              ],
            ),
            const SizedBox(height: 18),

            // Score + grade
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: session.scoreColor.withValues(alpha: 0.1),
                    border: Border.all(color: session.scoreColor, width: 2.5),
                  ),
                  child: Center(
                    child: Text(session.grade,
                        style: TextStyle(
                          color: session.scoreColor,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        )),
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${session.safetyScore.toInt()}/100',
                      style: TextStyle(
                        color: session.scoreColor,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text('Safety Score',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(session.startTime),
                      style: const TextStyle(
                          color: Color(0xFF636366), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Route
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.15),
                    width: 1),
              ),
              child: Row(
                children: [
                  Column(
                    children: [
                      const Icon(Icons.radio_button_checked,
                          color: Color(0xFF34C759), size: 14),
                      Container(
                          width: 1.5,
                          height: 20,
                          color: const Color(0xFF1C1C2E)),
                      const Icon(Icons.location_on_rounded,
                          color: Color(0xFFFF2D55), size: 14),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.startLocation,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Text(session.endLocation,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Stats grid
            _statRow('Duration', _formatDuration(session.duration),
                Icons.timer_rounded, const Color(0xFF5E5CE6)),
            const SizedBox(height: 8),
            _statRow('Distance', _formatDist(session.distanceMeters),
                Icons.route_rounded, const Color(0xFF00D4FF)),
            const SizedBox(height: 8),
            _statRow(
                'Max Speed',
                '${session.maxSpeed.toStringAsFixed(1)} km/h',
                Icons.speed_rounded,
                const Color(0xFFFF2D55)),
            const SizedBox(height: 8),
            _statRow(
                'Avg Speed',
                '${session.avgSpeed.toStringAsFixed(1)} km/h',
                Icons.trending_flat_rounded,
                const Color(0xFF34C759)),
            const SizedBox(height: 14),

            // Events
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'DRIVING EVENTS',
                style: TextStyle(
                  color: Color(0xFF636366),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _eventTile('Hard Brakes', session.hardBrakes,
                    Icons.front_hand_rounded, const Color(0xFFFF9F0A)),
                const SizedBox(width: 8),
                _eventTile('Hard Accels', session.hardAccels,
                    Icons.arrow_upward_rounded, const Color(0xFFFF2D55)),
                const SizedBox(width: 8),
                _eventTile('Sharp Turns', session.sharpTurns,
                    Icons.turn_right_rounded, const Color(0xFF5E5CE6)),
                const SizedBox(width: 8),
                _eventTile('Overspeeds', session.overSpeeds,
                    Icons.speed_rounded, const Color(0xFFFF2D55)),
              ],
            ),
            if (session.drowsinessEvents > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF5E5CE6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF5E5CE6).withValues(alpha: 0.3),
                      width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bedtime_rounded,
                        color: Color(0xFF5E5CE6), size: 16),
                    const SizedBox(width: 10),
                    Text(
                      '${session.drowsinessEvents} Drowsiness event(s) detected',
                      style: const TextStyle(
                        color: Color(0xFF5E5CE6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: session.scoreColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _statRow(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF8E8E93), fontSize: 12)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              )),
        ],
      ),
    );
  }

  Widget _eventTile(
      String label, int count, IconData icon, Color color) {
    final hasEvent = count > 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: hasEvent
              ? color.withValues(alpha: 0.08)
              : const Color(0xFF0F0F18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasEvent
                ? color.withValues(alpha: 0.3)
                : const Color(0xFF1C1C2E),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: hasEvent ? color : const Color(0xFF3A3A4A),
                size: 16),
            const SizedBox(height: 4),
            Text('$count',
                style: TextStyle(
                  color: hasEvent ? color : Colors.grey[700],
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                )),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(color: Color(0xFF636366), fontSize: 8),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
