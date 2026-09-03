import 'dart:async';

import 'package:geolocator/geolocator.dart' as geo;
import 'package:magiclane_maps_flutter/magiclane_maps_flutter.dart';

/// Coordinates, downloads, and route calculation for the on-device map.
///
/// A road-map package contains both rendered map data and the graph used by
/// Magic Lane's local pathfinder. Route calculation deliberately disallows an
/// online fallback so a successful result is proof that local routing works.
final class MapService {
  static final RectangleGeographicArea keralaBounds = RectangleGeographicArea(
    topLeft: Coordinates.fromLatLong(12.80, 74.80),
    bottomRight: Coordinates.fromLatLong(8.20, 77.60),
  );

  List<ContentStoreItem> installedKeralaMaps() {
    return ContentStore.getLocalContentList(ContentType.roadMap)
        .where((item) => item.isCompleted && _isKeralaOrIndia(item))
        .toList(growable: false);
  }

  Future<List<ContentStoreItem>> availableKeralaMaps() {
    final completer = Completer<List<ContentStoreItem>>();
    final listener = ContentStore.asyncGetStoreFilteredList(
      type: ContentType.roadMap,
      countries: const ['IND'],
      area: keralaBounds,
      onComplete: (error, items) {
        if (completer.isCompleted) return;
        if (error != GemError.success) {
          completer.completeError(
            MapServiceException(_catalogueErrorMessage(error)),
          );
          return;
        }
        final candidates = items.where(_isKeralaOrIndia).toList()
          ..sort((a, b) {
            final aKerala = a.name.toLowerCase().contains('kerala');
            final bKerala = b.name.toLowerCase().contains('kerala');
            if (aKerala != bKerala) return aKerala ? -1 : 1;
            return a.totalSize.compareTo(b.totalSize);
          });
        completer.complete(candidates);
      },
    );
    if (listener == null && !completer.isCompleted) {
      completer.completeError(
        const MapServiceException('The offline map catalogue did not start.'),
      );
    }
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw const MapServiceException(
        'Timed out while loading the offline map catalogue.',
      ),
    );
  }

  Future<Coordinates> currentCoordinates() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      throw const MapServiceException(
        'Turn on Location/GPS before calculating a route.',
      );
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied) {
      throw const MapServiceException('Location permission was denied.');
    }
    if (permission == geo.LocationPermission.deniedForever) {
      throw const MapServiceException(
        'Location permission is blocked. Enable it in Android Settings.',
      );
    }

    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return Coordinates.fromLatLong(position.latitude, position.longitude);
  }

  Future<Route> calculateOfflineRoute({
    required Coordinates start,
    required Coordinates destination,
  }) {
    final completer = Completer<Route>();
    final preferences = RoutePreferences(
      transportMode: RouteTransportMode.car,
      routeType: RouteType.fastest,
      allowOnlineCalculation: false,
    );
    final task = RoutingService.calculateRoute(
      [Landmark.withCoordinates(start), Landmark.withCoordinates(destination)],
      preferences,
      (error, routes) {
        if (completer.isCompleted) return;
        if (error == GemError.success && routes.isNotEmpty) {
          completer.complete(routes.first);
        } else {
          completer.completeError(
            MapServiceException(_routeErrorMessage(error)),
          );
        }
      },
    );
    if (task == null && !completer.isCompleted) {
      completer.completeError(
        const MapServiceException('Offline route calculation did not start.'),
      );
    }
    return completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw const MapServiceException(
        'Offline route calculation timed out.',
      ),
    );
  }

  bool _isKeralaOrIndia(ContentStoreItem item) {
    final label = '${item.chapterName} ${item.name}'.toLowerCase();
    return label.contains('kerala') || item.countryCodes.contains('IND');
  }

  String _routeErrorMessage(GemError error) {
    if (error == GemError.connectionRequired) {
      return 'The downloaded map does not cover both route points. Download '
          'the required Kerala road map and try again.';
    }
    if (error == GemError.waypointAccess) {
      return 'No drivable road could be reached near one of the route points.';
    }
    return 'Offline route calculation failed: $error';
  }

  String _catalogueErrorMessage(GemError error) {
    if (error == GemError.noConnection ||
        error == GemError.connectionRequired ||
        error == GemError.connection ||
        error == GemError.networkFailed ||
        error == GemError.networkTimeout ||
        error == GemError.networkCouldntResolveHost) {
      return 'The phone needs internet access to list and download the Kerala '
          'map. Once downloaded, route calculation works offline.';
    }
    if (error == GemError.invalidInput ||
        error == GemError.accessDenied ||
        error == GemError.activation) {
      return 'Magic Lane did not authorize the Project API Key: $error';
    }
    return 'Could not load offline maps: $error';
  }
}

final class MapServiceException implements Exception {
  const MapServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
