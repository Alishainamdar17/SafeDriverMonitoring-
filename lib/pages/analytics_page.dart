import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:safe_drive_monitor/services/live_drive_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ANALYTICS PAGE — Live data from LiveDriveState
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with TickerProviderStateMixin {

  late AnimationController _entryController;
  late Animation<double> _entryAnim;

  final LiveDriveState _liveState = LiveDriveState.instance;

  // ── Computed from live data ────────────────────────────────────────────────

  /// Safety scores of completed trips (oldest → newest, max 8 for chart)
  List<double> get _tripScores {
    final h = _liveState.history;
    if (h.isEmpty) return [];
    // history is newest-first, so reverse for chronological order
    final scores = h.reversed.map((s) => s.safetyScore).toList();
    // show last 8 trips
    return scores.length > 8 ? scores.sublist(scores.length - 8) : scores;
  }

  /// Last 7 completed trips mapped to weekday buckets for the bar chart.
  /// Returns a list of 7 entries: [dayLabel, avgScore or -1 if no data]
  List<_DayScore> get _weeklyScores {
    final now = DateTime.now();
    // Build buckets: last 7 days (today = index 6)
    final buckets = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return _DayScore(
        label: _dayLabel(date.weekday),
        date: date,
        scores: [],
        isToday: i == 6,
      );
    });

    for (final session in _liveState.history) {
      final diff = now.difference(session.startTime).inDays;
      if (diff >= 0 && diff < 7) {
        final idx = 6 - diff;
        buckets[idx].scores.add(session.safetyScore);
      }
    }
    return buckets;
  }

  String _dayLabel(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  double get _avgSafetyScore {
    final scores = _tripScores;
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  double get _bestScore {
    final scores = _tripScores;
    if (scores.isEmpty) return 0;
    return scores.reduce(max);
  }

  double get _worstScore {
    final scores = _tripScores;
    if (scores.isEmpty) return 0;
    return scores.reduce(min);
  }

  String get _overallGrade {
    if (_avgSafetyScore >= 90) return 'A+';
    if (_avgSafetyScore >= 80) return 'A';
    if (_avgSafetyScore >= 70) return 'B';
    if (_avgSafetyScore >= 55) return 'C';
    if (_avgSafetyScore > 0)   return 'D';
    return '--';
  }

  Color get _gradeColor {
    if (_avgSafetyScore >= 80) return const Color(0xFF34C759);
    if (_avgSafetyScore >= 55) return const Color(0xFFFF9F0A);
    if (_avgSafetyScore > 0)   return const Color(0xFFFF2D55);
    return const Color(0xFF636366);
  }

  int get _totalDrives       => _liveState.totalTrips;
  double get _totalDistanceKm => _liveState.totalDistanceKm;
  Duration get _totalDriveTime => _liveState.totalDriveTime;
  int get _totalHardBrakes   => _liveState.totalHardBrakes;
  int get _totalHardAccels   => _liveState.totalHardAccels;
  int get _totalSharpTurns   => _liveState.totalSharpTurns;
  int get _totalOverSpeeds   => _liveState.totalOverSpeeds;

  bool get _hasData => _totalDrives > 0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _entryController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    )..forward();
    _entryAnim = CurvedAnimation(
        parent: _entryController, curve: Curves.easeOut);
    _liveState.addListener(_onLiveUpdate);
  }

  void _onLiveUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entryController.dispose();
    _liveState.removeListener(_onLiveUpdate);
    super.dispose();
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
              Expanded(
                child: _hasData
                    ? ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        children: [
                          // Live drive banner (if currently driving)
                          if (_liveState.hasDrive) _buildLiveBanner(),
                          if (_liveState.hasDrive) const SizedBox(height: 14),
                          _buildOverallScoreCard(),
                          const SizedBox(height: 14),
                          _buildQuickStatsRow(),
                          const SizedBox(height: 14),
                          _buildWeeklyChart(),
                          const SizedBox(height: 14),
                          if (_tripScores.length >= 2) ...[
                            _buildTripTrendChart(),
                            const SizedBox(height: 14),
                          ],
                          _buildEventBreakdown(),
                          const SizedBox(height: 14),
                          _buildDrivingInsights(),
                          const SizedBox(height: 14),
                          _buildAdaptiveLearning(),
                        ],
                      )
                    : _buildEmptyState(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  LIVE BANNER (shown while a drive is in progress)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLiveBanner() {
    final cur = _liveState.current!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF34C759).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF34C759).withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: const Color(0xFF34C759).withOpacity(0.7),
                blurRadius: 6,
              )],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DRIVE IN PROGRESS',
                    style: TextStyle(
                      color: Color(0xFF34C759), fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1.5,
                    )),
                Text(
                  'Score: ${cur.safetyScore.toInt()}/100  ·  '
                  '${(cur.distanceKm).toStringAsFixed(1)} km  ·  '
                  '${cur.currentSpeed.toStringAsFixed(0)} km/h',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          Text('LIVE',
              style: TextStyle(
                color: const Color(0xFF34C759).withOpacity(0.8),
                fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1,
              )),
        ],
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
          Icon(Icons.bar_chart_rounded, color: Colors.grey[700], size: 56),
          const SizedBox(height: 16),
          Text('No trip data yet',
              style: TextStyle(
                color: Colors.grey[500], fontSize: 16,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          Text('Complete a drive to see your analytics',
              style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          const SizedBox(height: 24),
          // Show live drive info if currently driving
          if (_liveState.hasDrive) _buildLiveBanner(),
        ],
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
        border: Border(bottom: BorderSide(color: Color(0xFF1C1C2E), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ANALYTICS',
                  style: TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w800, letterSpacing: 2,
                    fontFamily: 'monospace',
                  )),
              Text('Driving performance insights',
                  style: TextStyle(color: Color(0xFF636366), fontSize: 11)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF34C759).withOpacity(0.3), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded,
                    color: Color(0xFF34C759), size: 14),
                const SizedBox(width: 5),
                Text('$_totalDrives TRIPS',
                    style: const TextStyle(
                      color: Color(0xFF34C759), fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  OVERALL SCORE CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOverallScoreCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _gradeColor.withOpacity(0.12),
            _gradeColor.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gradeColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gradeColor.withOpacity(0.12),
              border: Border.all(color: _gradeColor, width: 2.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_overallGrade,
                    style: TextStyle(
                      color: _gradeColor, fontSize: 30,
                      fontWeight: FontWeight.w900,
                    )),
                Text('GRADE',
                    style: TextStyle(
                      color: _gradeColor.withOpacity(0.7),
                      fontSize: 8, fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overall Score',
                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  _hasData
                      ? '${_avgSafetyScore.toStringAsFixed(1)}/100'
                      : '--/100',
                  style: TextStyle(
                    color: _gradeColor, fontSize: 32,
                    fontWeight: FontWeight.w900, fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _avgSafetyScore / 100,
                    backgroundColor: const Color(0xFF1C1C2E),
                    valueColor: AlwaysStoppedAnimation(_gradeColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                if (_hasData)
                  Row(
                    children: [
                      _miniScoreBadge('Best', _bestScore,
                          const Color(0xFF34C759)),
                      const SizedBox(width: 8),
                      _miniScoreBadge('Worst', _worstScore,
                          const Color(0xFFFF2D55)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniScoreBadge(String label, double score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          Text('${score.toInt()}',
              style: TextStyle(
                color: color, fontSize: 11,
                fontWeight: FontWeight.w800, fontFamily: 'monospace',
              )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  QUICK STATS ROW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildQuickStatsRow() {
    final hours = _totalDriveTime.inHours;
    final mins  = _totalDriveTime.inMinutes % 60;
    return Row(
      children: [
        Expanded(child: _statCard(
          '${_totalDistanceKm.toStringAsFixed(1)} km',
          'Total Distance', Icons.route_rounded, const Color(0xFF00D4FF))),
        const SizedBox(width: 10),
        Expanded(child: _statCard(
          '${hours}h ${mins}m',
          'Drive Time', Icons.timer_rounded, const Color(0xFF5E5CE6))),
        const SizedBox(width: 10),
        Expanded(child: _statCard(
          '$_totalDrives',
          'Total Trips', Icons.directions_car_rounded,
          const Color(0xFF34C759))),
        const SizedBox(width: 10),
        Expanded(child: _statCard(
          _hasData
              ? '${(_totalDistanceKm / _totalDrives).toStringAsFixed(1)} km'
              : '--',
          'Avg / Trip', Icons.straighten_rounded, const Color(0xFFFF9F0A))),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                  color: color, fontSize: 13,
                  fontWeight: FontWeight.w800, fontFamily: 'monospace',
                )),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF636366), fontSize: 8),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  WEEKLY SAFETY CHART — real day buckets from live history
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWeeklyChart() {
    final days = _weeklyScores;
    return _card(
      title: 'Weekly Safety Scores',
      icon: Icons.calendar_view_week_rounded,
      accent: const Color(0xFF00D4FF),
      child: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(days.length, (i) {
            final day   = days[i];
            final score = day.avgScore; // -1 if no trips that day
            final hasData = score >= 0;
            final color = !hasData
                ? const Color(0xFF1C1C2E)
                : score >= 80
                    ? const Color(0xFF34C759)
                    : score >= 55
                        ? const Color(0xFFFF9F0A)
                        : const Color(0xFFFF2D55);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      hasData ? '${score.toInt()}' : '',
                      style: TextStyle(
                        color: color, fontSize: 9,
                        fontWeight: FontWeight.w700, fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 400 + i * 60),
                      curve: Curves.easeOut,
                      height: hasData ? (score / 100) * 100 : 6,
                      decoration: BoxDecoration(
                        color: day.isToday
                            ? color
                            : color.withOpacity(hasData ? 0.5 : 1.0),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: day.isToday && hasData
                            ? [BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8)]
                            : [],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(day.label,
                        style: TextStyle(
                          color: day.isToday
                              ? Colors.white
                              : const Color(0xFF636366),
                          fontSize: 9, fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  TRIP SCORE TREND (sparkline of completed trips)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTripTrendChart() {
    final scores = _tripScores;
    return _card(
      title: 'Trip Score Trend',
      icon: Icons.show_chart_rounded,
      accent: const Color(0xFF5E5CE6),
      child: Column(
        children: [
          SizedBox(
            height: 90,
            child: CustomPaint(
              size: const Size(double.infinity, 90),
              painter: _SparklinePainter(
                data: scores,
                color: const Color(0xFF5E5CE6),
                limitY: 80,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(scores.length, (i) => Text(
              'T${i + 1}',
              style: const TextStyle(
                color: Color(0xFF636366), fontSize: 9,
                fontFamily: 'monospace',
              ),
            )),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(width: 10, height: 2,
                  color: const Color(0xFF5E5CE6).withOpacity(0.5)),
              const SizedBox(width: 4),
              const Text('Score trend',
                  style: TextStyle(color: Color(0xFF636366), fontSize: 10)),
              const SizedBox(width: 14),
              Container(width: 10, height: 1,
                  color: const Color(0xFF34C759).withOpacity(0.6)),
              const SizedBox(width: 4),
              const Text('80 target',
                  style: TextStyle(color: Color(0xFF636366), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  EVENT BREAKDOWN — all from live state
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEventBreakdown() {
    // Dynamic max bar: at least 1 to avoid divide-by-zero
    final maxBrakes  = max(_totalHardBrakes, 1);
    final maxAccels  = max(_totalHardAccels, 1);
    final maxTurns   = max(_totalSharpTurns, 1);
    final maxOver    = max(_totalOverSpeeds, 1);
    final allMax     = max(maxBrakes, max(maxAccels, max(maxTurns, maxOver)));

    return _card(
      title: 'Event Breakdown',
      icon: Icons.warning_amber_rounded,
      accent: const Color(0xFFFF9F0A),
      child: Column(
        children: [
          _eventRow('Hard Brakes', _totalHardBrakes, allMax,
              const Color(0xFFFF9F0A), Icons.front_hand_rounded),
          const SizedBox(height: 10),
          _eventRow('Hard Accelerations', _totalHardAccels, allMax,
              const Color(0xFFFF2D55), Icons.arrow_upward_rounded),
          const SizedBox(height: 10),
          _eventRow('Sharp Turns', _totalSharpTurns, allMax,
              const Color(0xFF5E5CE6), Icons.turn_right_rounded),
          const SizedBox(height: 10),
          _eventRow('Overspeed Events', _totalOverSpeeds, allMax,
              const Color(0xFFFF2D55), Icons.speed_rounded),
        ],
      ),
    );
  }

  Widget _eventRow(
      String label, int count, int maxForBar, Color color, IconData icon) {
    final ratio = maxForBar > 0 ? (count / maxForBar).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  Text('$count',
                      style: TextStyle(
                        color: color, fontSize: 12,
                        fontWeight: FontWeight.w800, fontFamily: 'monospace',
                      )),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: const Color(0xFF1C1C2E),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  DRIVING INSIGHTS — generated from live data
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDrivingInsights() {
    final insights = _generateInsights();
    return _card(
      title: 'AI Driving Insights',
      icon: Icons.psychology_rounded,
      accent: const Color(0xFF00D4FF),
      child: Column(
        children: insights
            .map((i) => _insightTile(i['text']!, i['type']!))
            .toList(),
      ),
    );
  }

  List<Map<String, String>> _generateInsights() {
    final insights = <Map<String, String>>[];

    if (!_hasData) {
      insights.add({
        'text': 'Complete your first drive to receive personalized insights.',
        'type': 'warn',
      });
      return insights;
    }

    // Overall score
    if (_avgSafetyScore >= 80) {
      insights.add({
        'text': 'Great overall driving! Maintain your smooth control habits.',
        'type': 'good',
      });
    } else if (_avgSafetyScore >= 60) {
      insights.add({
        'text': 'Your score can improve — focus on reducing sudden events.',
        'type': 'warn',
      });
    } else {
      insights.add({
        'text': 'Driving safety needs attention. Consider defensive driving training.',
        'type': 'bad',
      });
    }

    // Overspeed
    final overPerTrip = _totalDrives > 0
        ? _totalOverSpeeds / _totalDrives
        : 0.0;
    if (overPerTrip > 3) {
      insights.add({
        'text': 'Frequent overspeeding detected. Maintain speed limits for safety.',
        'type': 'bad',
      });
    } else if (overPerTrip > 1) {
      insights.add({
        'text': 'Occasional speeding observed. Try to stay within limits.',
        'type': 'warn',
      });
    } else {
      insights.add({
        'text': 'Excellent speed compliance — you rarely exceed speed limits.',
        'type': 'good',
      });
    }

    // Hard brakes
    final brakesPerTrip = _totalDrives > 0
        ? _totalHardBrakes / _totalDrives
        : 0.0;
    if (brakesPerTrip > 3) {
      insights.add({
        'text': 'High hard-braking rate. Increase following distance to brake earlier.',
        'type': 'bad',
      });
    } else if (brakesPerTrip < 1) {
      insights.add({
        'text': 'Smooth braking pattern — great for fuel efficiency and safety.',
        'type': 'good',
      });
    }

    // Sharp turns
    if (_totalSharpTurns > _totalDrives * 2) {
      insights.add({
        'text': 'Many sharp turns detected. Slow down before corners.',
        'type': 'warn',
      });
    }

    // Trip count milestone
    if (_totalDrives >= 10) {
      insights.add({
        'text': '10+ trips recorded. AI profile is building a reliable baseline.',
        'type': 'good',
      });
    }

    return insights;
  }

  Widget _insightTile(String text, String type) {
    final color = type == 'good'
        ? const Color(0xFF34C759)
        : type == 'warn'
            ? const Color(0xFFFF9F0A)
            : const Color(0xFFFF2D55);
    final icon = type == 'good'
        ? Icons.check_circle_rounded
        : type == 'warn'
            ? Icons.info_rounded
            : Icons.cancel_rounded;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ADAPTIVE LEARNING STATUS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAdaptiveLearning() {
    final avgOverPerTrip = _totalDrives > 0
        ? _totalOverSpeeds / _totalDrives
        : 0.0;
    final totalDriveSeconds = _totalDriveTime.inSeconds;
    final avgEventRate = totalDriveSeconds > 0
        ? (_totalHardBrakes + _totalHardAccels + _totalSharpTurns) /
            totalDriveSeconds
        : 0.0;

    return _card(
      title: 'Adaptive Learning Status',
      icon: Icons.auto_awesome_rounded,
      accent: const Color(0xFF5E5CE6),
      child: Column(
        children: [
          _learningRow('Profile Initialized', _hasData),
          const SizedBox(height: 8),
          _learningRow('Adaptive Learning', _totalDrives >= 3),
          const SizedBox(height: 12),
          _learningStat('Profile Drives',
              '$_totalDrives drive${_totalDrives == 1 ? '' : 's'} analysed'),
          const SizedBox(height: 6),
          _learningStat('Avg Overspeed / Trip',
              avgOverPerTrip.toStringAsFixed(2)),
          const SizedBox(height: 6),
          _learningStat('Avg Event Rate',
              '${avgEventRate.toStringAsFixed(4)} /sec'),
          const SizedBox(height: 6),
          _learningStat('Total Distance',
              '${_totalDistanceKm.toStringAsFixed(2)} km'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF5E5CE6).withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF5E5CE6).withOpacity(0.2), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF5E5CE6), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _totalDrives < 3
                        ? 'Complete ${3 - _totalDrives} more trip${(3 - _totalDrives) == 1 ? '' : 's'} to activate adaptive learning.'
                        : 'AI is learning your driving patterns to personalise alerts and scoring over time.',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _learningRow(String label, bool enabled) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFF34C759)
                : const Color(0xFF636366),
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [BoxShadow(
                    color: const Color(0xFF34C759).withOpacity(0.5),
                    blurRadius: 6)]
                : [],
          ),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        const Spacer(),
        Text(enabled ? 'ACTIVE' : 'OFF',
            style: TextStyle(
              color: enabled
                  ? const Color(0xFF34C759)
                  : const Color(0xFF636366),
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
            )),
      ],
    );
  }

  Widget _learningStat(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
        Text(value,
            style: const TextStyle(
              color: Colors.white, fontSize: 11,
              fontWeight: FontWeight.w600, fontFamily: 'monospace',
            )),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SHARED CARD WRAPPER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _card({
    required String title,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3, height: 14,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: accent, size: 15),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPER — day bucket for weekly chart
// ─────────────────────────────────────────────────────────────────────────────
class _DayScore {
  final String label;
  final DateTime date;
  final List<double> scores;
  final bool isToday;

  _DayScore({
    required this.label,
    required this.date,
    required this.scores,
    required this.isToday,
  });

  /// Average score for this day, or -1 if no trips
  double get avgScore {
    if (scores.isEmpty) return -1;
    return scores.reduce((a, b) => a + b) / scores.length;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SPARKLINE PAINTER (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double limitY;

  const _SparklinePainter({
    required this.data, required this.color, required this.limitY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    const minVal = 0.0;
    const maxVal = 100.0;
    final range  = maxVal - minVal;
    final stepX  = size.width / (data.length - 1);

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1A1A28)
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final y = size.height * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Target line (dashed)
    final limitYPos = size.height - ((limitY - minVal) / range) * size.height;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, limitYPos), Offset(x + 8, limitYPos),
        Paint()
          ..color = const Color(0xFF34C759).withOpacity(0.5)
          ..strokeWidth = 1,
      );
      x += 14;
    }

    // Path
    final path     = Path();
    final fillPath = Path();
    for (int i = 0; i < data.length; i++) {
      final px = i * stepX;
      final py = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(px, py);
        fillPath.moveTo(px, size.height);
        fillPath.lineTo(px, py);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height -
            ((data[i - 1] - minVal) / range) * size.height;
        final cpX = (prevX + px) / 2;
        path.cubicTo(cpX, prevY, cpX, py, px, py);
        fillPath.cubicTo(cpX, prevY, cpX, py, px, py);
      }
    }
    fillPath.lineTo((data.length - 1) * stepX, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    final lastX = (data.length - 1) * stepX;
    final lastY =
        size.height - ((data.last - minVal) / range) * size.height;
    canvas.drawCircle(Offset(lastX, lastY), 7,
        Paint()
          ..color = color.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = color);
    canvas.drawCircle(
        Offset(lastX, lastY), 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color;
}