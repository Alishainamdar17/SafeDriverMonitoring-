// // lib/pages/drive_detail_page.dart
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:safe_drive_monitor/models/drive.dart';
// import 'package:safe_drive_monitor/config/app_config.dart';

// class DriveDetailPage extends StatefulWidget {
//   final Drive drive;

//   const DriveDetailPage({super.key, required this.drive});

//   @override
//   State<DriveDetailPage> createState() => _DriveDetailPageState();
// }

// class _DriveDetailPageState extends State<DriveDetailPage> {
//   late final MapController _mapController;
//   bool _mapReady = false;

//   @override
//   void initState() {
//     super.initState();
//     _mapController = MapController();
//   }

//   @override
//   void dispose() {
//     _mapController.dispose();
//     super.dispose();
//   }

//   List<LatLng> get _routeLatLngs => widget.drive.routePoints
//       .map((p) => LatLng(p.latitude, p.longitude))
//       .toList();

//   LatLng? get _startPoint =>
//       _routeLatLngs.isNotEmpty ? _routeLatLngs.first : null;

//   LatLng? get _endPoint =>
//       _routeLatLngs.length > 1 ? _routeLatLngs.last : null;

//   void _fitRoute() {
//     if (!_mapReady || _routeLatLngs.isEmpty) return;
//     if (_routeLatLngs.length == 1) {
//       _mapController.move(_routeLatLngs.first, 15);
//       return;
//     }
//     final bounds = LatLngBounds.fromPoints(_routeLatLngs);
//     _mapController.fitCamera(
//       CameraFit.bounds(
//         bounds: bounds,
//         padding: const EdgeInsets.all(40),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final duration = Duration(seconds: widget.drive.durationSeconds);
//     final hasRoute = _routeLatLngs.isNotEmpty;

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.grey[900],
//         title: const Text(
//           'Drive Details',
//           style: TextStyle(color: Colors.white),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [

//           // ── Route Map ──────────────────────────────────────────────────
//           _buildInfoCard(
//             title: 'Route Map',
//             content: hasRoute ? _buildRouteMap() : _buildNoRoutePlaceholder(),
//           ),
//           const SizedBox(height: 16),

//           // ── Time ───────────────────────────────────────────────────────
//           _buildInfoCard(
//             title: 'Time',
//             content: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Start: ${widget.drive.startTime.toString().split('.')[0]}',
//                   style: TextStyle(color: Colors.grey[400]),
//                 ),
//                 if (widget.drive.endTime != null)
//                   Text(
//                     'End: ${widget.drive.endTime.toString().split('.')[0]}',
//                     style: TextStyle(color: Colors.grey[400]),
//                   ),
//                 Text(
//                   'Duration: ${duration.inHours}h '
//                   '${duration.inMinutes % 60}m '
//                   '${duration.inSeconds % 60}s',
//                   style: TextStyle(color: Colors.grey[400]),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),

//           // ── Speed ──────────────────────────────────────────────────────
//           _buildInfoCard(
//             title: 'Speed',
//             content: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Average: ${widget.drive.averageSpeed.toStringAsFixed(1)} km/h',
//                   style: TextStyle(color: Colors.grey[400]),
//                 ),
//                 Text(
//                   'Time Over Speed Limit: ${widget.drive.overSpeedDurationSeconds}s',
//                   style: TextStyle(color: Colors.grey[400]),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),

//           // ── Events ─────────────────────────────────────────────────────
//           _buildInfoCard(
//             title: 'Events',
//             content: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _buildEventSection(
//                     'Sudden Accelerations', widget.drive.suddenAccelerations),
//                 const SizedBox(height: 8),
//                 _buildEventSection(
//                     'Sudden Brakings', widget.drive.suddenBrakings),
//                 const SizedBox(height: 8),
//                 _buildEventSection('Sharp Turns', widget.drive.sharpTurns),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Map widgets ────────────────────────────────────────────────────────

//   Widget _buildRouteMap() {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(8),
//       child: SizedBox(
//         height: 260,
//         child: FlutterMap(
//           mapController: _mapController,
//           options: MapOptions(
//             initialCenter: _startPoint ?? const LatLng(20.5937, 78.9629),
//             initialZoom: 14,
//             onMapReady: () {
//               setState(() => _mapReady = true);
//               Future.delayed(const Duration(milliseconds: 200), _fitRoute);
//             },
//           ),
//           children: [
//             TileLayer(
//               urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//               userAgentPackageName: 'com.yourapp.safe_drive_monitor',
//             ),
//             PolylineLayer(
//               polylines: [
//                 Polyline(
//                   points: _routeLatLngs,
//                   strokeWidth: 4,
//                   color: Colors.blueAccent,
//                 ),
//               ],
//             ),
//             MarkerLayer(
//               markers: [
//                 if (_startPoint != null)
//                   Marker(
//                     point: _startPoint!,
//                     width: 36,
//                     height: 36,
//                     child: _MapMarker(
//                       color: Colors.green,
//                       icon: Icons.play_arrow,
//                       tooltip: 'Start',
//                     ),
//                   ),
//                 if (_endPoint != null)
//                   Marker(
//                     point: _endPoint!,
//                     width: 36,
//                     height: 36,
//                     child: _MapMarker(
//                       color: Colors.red,
//                       icon: Icons.flag,
//                       tooltip: 'End',
//                     ),
//                   ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildNoRoutePlaceholder() {
//     return Container(
//       height: 120,
//       decoration: BoxDecoration(
//         color: Colors.grey[850],
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey[700]!),
//       ),
//       child: const Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.map_outlined, color: Colors.grey, size: 36),
//             SizedBox(height: 8),
//             Text(
//               'No route data for this drive',
//               style: TextStyle(color: Colors.grey, fontSize: 13),
//             ),
//             SizedBox(height: 4),
//             Text(
//               'GPS tracking was not active',
//               style: TextStyle(color: Colors.grey, fontSize: 11),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Helpers ────────────────────────────────────────────────────────────

//   Widget _buildEventSection(String title, Map<int, int> events) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(title,
//             style: const TextStyle(
//                 color: Colors.white, fontWeight: FontWeight.bold)),
//         if (events.isEmpty)
//           Text('None',
//               style: TextStyle(color: Colors.grey[600], fontSize: 13))
//         else
//           ...events.entries.map((e) => Text(
//                 '${e.value} events at '
//                 '${DateTime.fromMillisecondsSinceEpoch(e.key * AppConfig.suddenEventGroupInterval * 1000).toString().split('.')[0]}',
//                 style: TextStyle(color: Colors.grey[400]),
//               )),
//       ],
//     );
//   }

//   Widget _buildInfoCard({required String title, required Widget content}) {
//     return Card(
//       color: Colors.grey[900],
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(title,
//                 style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             content,
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ── Marker widget ──────────────────────────────────────────────────────────

// class _MapMarker extends StatelessWidget {
//   final Color color;
//   final IconData icon;
//   final String tooltip;

//   const _MapMarker({
//     required this.color,
//     required this.icon,
//     required this.tooltip,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Tooltip(
//       message: tooltip,
//       child: Container(
//         decoration: BoxDecoration(
//           color: color,
//           shape: BoxShape.circle,
//           border: Border.all(color: Colors.white, width: 2),
//           boxShadow: const [
//             BoxShadow(
//                 color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
//           ],
//         ),
//         child: Icon(icon, color: Colors.white, size: 18),
//       ),
//     );
//   }
// }

// lib/pages/drive_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_drive_monitor/models/drive.dart';
import 'package:safe_drive_monitor/services/database_service.dart';
import 'package:safe_drive_monitor/config/app_config.dart';

class DriveDetailPage extends StatefulWidget {
  final Drive drive;

  /// When true the page polls the DB every 2 s and updates all UI live.
  final bool isLive;

  /// Required when isLive = true so we can re-fetch the current drive row.
  final DatabaseService? databaseService;

  const DriveDetailPage({
    super.key,
    required this.drive,
    this.isLive = false,
    this.databaseService,
  });

  @override
  State<DriveDetailPage> createState() => _DriveDetailPageState();
}

class _DriveDetailPageState extends State<DriveDetailPage>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  bool _mapReady = false;

  // ── Live polling ───────────────────────────────────────────────────────
  Timer? _liveTimer;

  /// The drive we're actually displaying — starts as widget.drive,
  /// gets replaced on every poll when isLive = true.
  late Drive _displayDrive;

  /// For the live elapsed-time ticker (separate 1-second timer)
  Timer? _clockTimer;

  // ── Pulse animation for LIVE badge ────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Expand/collapse sections ──────────────────────────────────────────
  bool _mapExpanded = true;
  bool _eventsExpanded = true;

  @override
  void initState() {
    super.initState();
    _displayDrive = widget.drive;
    _mapController = MapController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isLive) {
      // Poll DB for fresh drive data every 2 seconds
      _liveTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollLiveDrive());

      // Tick elapsed clock every second
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _clockTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVE POLLING
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pollLiveDrive() async {
    if (widget.databaseService == null || widget.drive.id == null) return;
    try {
      final drives = await widget.databaseService!.getDrives();
      final fresh = drives.where((d) => d.id == widget.drive.id).firstOrNull;
      if (fresh != null && mounted) {
        setState(() => _displayDrive = fresh);
        // Keep map centred on latest GPS point
        if (_mapReady && fresh.routePoints.isNotEmpty) {
          _mapController.move(
            LatLng(
              fresh.routePoints.last.latitude,
              fresh.routePoints.last.longitude,
            ),
            _mapController.camera.zoom,
          );
        }
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMPUTED GETTERS
  // ─────────────────────────────────────────────────────────────────────────
  List<LatLng> get _routeLatLngs => _displayDrive.routePoints
      .map((p) => LatLng(p.latitude, p.longitude))
      .toList();

  LatLng? get _startPoint =>
      _routeLatLngs.isNotEmpty ? _routeLatLngs.first : null;

  LatLng? get _currentPoint =>
      _routeLatLngs.length > 1 ? _routeLatLngs.last : null;

  Duration get _liveDuration => widget.isLive
      ? DateTime.now().difference(_displayDrive.startTime)
      : Duration(seconds: _displayDrive.durationSeconds);

  int get _safetyScore {
    int score = 100;
    final totalEvents =
        _displayDrive.suddenAccelerations.values.fold<int>(0, (a, b) => a + b) +
            _displayDrive.suddenBrakings.values.fold<int>(0, (a, b) => a + b) +
            _displayDrive.sharpTurns.values.fold<int>(0, (a, b) => a + b);
    score -= (totalEvents * 5).clamp(0, 40);
    score -= (_displayDrive.overSpeedDurationSeconds ~/ 30).clamp(0, 30);
    return score.clamp(0, 100);
  }

  void _fitRoute() {
    if (!_mapReady || _routeLatLngs.isEmpty) return;
    if (_routeLatLngs.length == 1) {
      _mapController.move(_routeLatLngs.first, 15);
      return;
    }
    final bounds = LatLngBounds.fromPoints(_routeLatLngs);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Live status banner ────────────────────────────────────────
          if (widget.isLive) _buildLiveBanner(),
          if (widget.isLive) const SizedBox(height: 14),

          // ── Safety Score ──────────────────────────────────────────────
          _buildSafetyScoreCard(),
          const SizedBox(height: 14),

          // ── Quick stats row ───────────────────────────────────────────
          _buildQuickStatsRow(),
          const SizedBox(height: 14),

          // ── Route Map ─────────────────────────────────────────────────
          _buildSection(
            title: 'Route Map',
            icon: Icons.map_outlined,
            isExpanded: _mapExpanded,
            onToggle: () => setState(() => _mapExpanded = !_mapExpanded),
            child: _routeLatLngs.isNotEmpty
                ? _buildRouteMap()
                : _buildNoRoutePlaceholder(),
          ),
          const SizedBox(height: 14),

          // ── Time ──────────────────────────────────────────────────────
          _buildSection(
            title: 'Time',
            icon: Icons.schedule_rounded,
            child: _buildTimeContent(),
          ),
          const SizedBox(height: 14),

          // ── Speed ─────────────────────────────────────────────────────
          _buildSection(
            title: 'Speed',
            icon: Icons.speed_rounded,
            child: _buildSpeedContent(),
          ),
          const SizedBox(height: 14),

          // ── Events ────────────────────────────────────────────────────
          _buildSection(
            title: 'Events',
            icon: Icons.warning_amber_rounded,
            isExpanded: _eventsExpanded,
            onToggle: () =>
                setState(() => _eventsExpanded = !_eventsExpanded),
            child: _buildEventsContent(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D1A),
      elevation: 0,
      title: Text(
        widget.isLive ? 'Live Drive' : 'Drive Details',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (!widget.isLive)
          IconButton(
            icon: const Icon(Icons.fit_screen_rounded,
                color: Colors.white70, size: 20),
            tooltip: 'Fit route',
            onPressed: _fitRoute,
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
            height: 1, color: Colors.deepPurple.withOpacity(0.3)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVE BANNER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLiveBanner() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, __) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade900
                  .withOpacity(0.3 + _pulseAnimation.value * 0.2),
              Colors.deepPurple.shade900.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.redAccent
                .withOpacity(0.3 + _pulseAnimation.value * 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.redAccent
                    .withOpacity(_pulseAnimation.value),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'LIVE  •  Updating every 2 seconds',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              '${_displayDrive.routePoints.length} GPS pts',
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAFETY SCORE CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSafetyScoreCard() {
    final score = _safetyScore;
    final color = score >= 80
        ? Colors.green
        : score >= 50
            ? Colors.orange
            : Colors.red;
    final label = score >= 80
        ? 'Safe'
        : score >= 50
            ? 'Caution'
            : 'Unsafe';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          // Score circle
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety Score',
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 5,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
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
  // QUICK STATS ROW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildQuickStatsRow() {
    final dur = _liveDuration;
    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            Icons.timer_outlined,
            _formatDuration(dur.inSeconds),
            'Duration',
            Colors.cyanAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            Icons.speed_rounded,
            '${_displayDrive.averageSpeed.toStringAsFixed(1)}',
            'km/h Avg',
            Colors.purpleAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            Icons.route_rounded,
            '${_displayDrive.routePoints.length}',
            'GPS Points',
            Colors.tealAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION WRAPPER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    bool isExpanded = true,
    VoidCallback? onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14141F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Icon(icon, color: Colors.deepPurpleAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onToggle != null) ...[
                    const Spacer(),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey[600],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Divider
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          // Content
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAP
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRouteMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 280,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _startPoint ?? const LatLng(20.5937, 78.9629),
            initialZoom: 14,
            onMapReady: () {
              setState(() => _mapReady = true);
              Future.delayed(
                  const Duration(milliseconds: 200), _fitRoute);
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.yourapp.safe_drive_monitor',
            ),
            // Completed route (blue)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routeLatLngs,
                  strokeWidth: 4,
                  color: Colors.blueAccent,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                // Start marker (green)
                if (_startPoint != null)
                  Marker(
                    point: _startPoint!,
                    width: 36,
                    height: 36,
                    child: _MapMarker(
                      color: Colors.green,
                      icon: Icons.play_arrow,
                      tooltip: 'Start',
                    ),
                  ),
                // Current position (live) or end (past)
                if (_currentPoint != null)
                  Marker(
                    point: _currentPoint!,
                    width: 36,
                    height: 36,
                    child: widget.isLive
                        ? _LivePositionMarker(pulse: _pulseAnimation)
                        : _MapMarker(
                            color: Colors.red,
                            icon: Icons.flag,
                            tooltip: 'End',
                          ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRoutePlaceholder() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, color: Colors.grey[700], size: 36),
            const SizedBox(height: 8),
            Text(
              widget.isLive
                  ? 'Waiting for GPS signal...'
                  : 'No route data for this drive',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TIME CONTENT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTimeContent() {
    final dur = _liveDuration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataRow(
          'Start',
          _displayDrive.startTime.toString().split('.')[0],
          Colors.grey[300]!,
        ),
        if (_displayDrive.endTime != null && !widget.isLive)
          _buildDataRow(
            'End',
            _displayDrive.endTime.toString().split('.')[0],
            Colors.grey[300]!,
          ),
        _buildDataRow(
          'Duration',
          _formatDuration(dur.inSeconds),
          widget.isLive ? Colors.cyanAccent : Colors.grey[300]!,
        ),
        if (widget.isLive)
          _buildDataRow('Status', '🟢 In Progress', Colors.greenAccent),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SPEED CONTENT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSpeedContent() {
    final overSpeed = _displayDrive.overSpeedDurationSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataRow(
          'Average Speed',
          '${_displayDrive.averageSpeed.toStringAsFixed(1)} km/h',
          Colors.grey[300]!,
        ),
        _buildDataRow(
          'Speed Limit',
          '${AppConfig.speedLimit.toStringAsFixed(0)} km/h',
          Colors.grey[300]!,
        ),
        _buildDataRow(
          'Time Over Limit',
          '${overSpeed}s',
          overSpeed > 0 ? Colors.orangeAccent : Colors.greenAccent,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EVENTS CONTENT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEventsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEventSection(
          'Sudden Accelerations',
          Icons.arrow_upward_rounded,
          Colors.orangeAccent,
          _displayDrive.suddenAccelerations,
        ),
        const SizedBox(height: 12),
        _buildEventSection(
          'Sudden Brakings',
          Icons.arrow_downward_rounded,
          Colors.redAccent,
          _displayDrive.suddenBrakings,
        ),
        const SizedBox(height: 12),
        _buildEventSection(
          'Sharp Turns',
          Icons.turn_right_rounded,
          Colors.purpleAccent,
          _displayDrive.sharpTurns,
        ),
      ],
    );
  }

  Widget _buildEventSection(
    String title,
    IconData icon,
    Color color,
    Map<int, int> events,
  ) {
    final total = events.values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: total > 0
                    ? color.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$total total',
                style: TextStyle(
                  color: total > 0 ? color : Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (events.isEmpty)
          Text('None',
              style: TextStyle(color: Colors.grey[600], fontSize: 12))
        else
          ...events.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${e.value} event${e.value > 1 ? 's' : ''} at '
                '${DateTime.fromMillisecondsSinceEpoch(e.key * AppConfig.suddenEventGroupInterval * 1000).toString().split('.')[0]}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDataRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATIC MAP MARKER
// ─────────────────────────────────────────────────────────────────────────────
class _MapMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String tooltip;

  const _MapMarker({
    required this.color,
    required this.icon,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black45,
                blurRadius: 4,
                offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE POSITION MARKER — pulsing blue dot
// ─────────────────────────────────────────────────────────────────────────────
class _LivePositionMarker extends StatelessWidget {
  final Animation<double> pulse;

  const _LivePositionMarker({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          Container(
            width: 32 * pulse.value,
            height: 32 * pulse.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueAccent.withOpacity(0.3 * (1 - pulse.value)),
            ),
          ),
          // Inner solid dot
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
