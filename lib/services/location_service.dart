import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'api_service.dart';

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  Future<LocationPermission?> permissionStatus() async {
    try {
      return await Geolocator.checkPermission();
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> hasLocationPermission() async {
    final permission = await permissionStatus();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<LocationResult> requestCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw ApiException(
          'Turn on location services to use your current location.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw ApiException('Location permission was denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw ApiException(
          'Location permission is permanently denied. Enable it in Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final location = await formatPosition(position);
      return LocationResult(position: position, location: location);
    } on MissingPluginException {
      throw ApiException(
        'Location service is not ready. Restart the app and try again.',
      );
    }
  }

  Future<String> formatPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = <String>[];
        for (final value in [
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.country,
        ]) {
          final trimmed = value?.trim();
          if (trimmed != null &&
              trimmed.isNotEmpty &&
              !parts.contains(trimmed)) {
            parts.add(trimmed);
          }
        }
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {
      // Fall back to coordinates if reverse geocoding is unavailable.
    }

    return '${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)}';
  }
}

class LocationResult {
  const LocationResult({required this.position, required this.location});

  final Position position;
  final String location;
}
