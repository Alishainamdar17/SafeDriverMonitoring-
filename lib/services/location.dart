// lib/services/location_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPoint {
  final double latitude;
  final double longitude;
  final double speedKmh;
  final DateTime timestamp;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'lat':   latitude,
    'lng':   longitude,
    'speed': speedKmh,
    'time':  timestamp.millisecondsSinceEpoch,
  };

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
    latitude:  (json['lat']   as num).toDouble(),
    longitude: (json['lng']   as num).toDouble(),
    speedKmh:  (json['speed'] as num).toDouble(),
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
  );
}

class LocationService {
  final StreamController<LocationPoint> _locationStream =
      StreamController<LocationPoint>.broadcast();

  StreamSubscription<Position>? _positionSubscription;
  final List<LocationPoint> _routePoints = [];
  bool _isTracking = false;

  Stream<LocationPoint> get locationStream => _locationStream.stream;
  List<LocationPoint> get routePoints => List.unmodifiable(_routePoints);
  bool get isTracking => _isTracking;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission permanently denied.');
      return false;
    }

    return true;
  }

  Future<void> startTracking() async {
    final granted = await requestPermission();
    if (!granted) return;

    _routePoints.clear();
    _isTracking = true;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (Position position) {
        final point = LocationPoint(
          latitude:  position.latitude,
          longitude: position.longitude,
          speedKmh:  position.speed * 3.6,
          timestamp: DateTime.now(),
        );
        _routePoints.add(point);
        _locationStream.add(point);
      },
      onError: (e) => debugPrint('Location error: $e'),
    );
  }

  Future<List<LocationPoint>> stopTracking() async {
    _isTracking = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    return List.from(_routePoints);
  }

  Future<void> dispose() async {
    await stopTracking();
    await _locationStream.close();
  }
}