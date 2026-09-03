import 'dart:async';

import 'package:flutter/material.dart' hide Route;
import 'package:magiclane_maps_flutter/magiclane_maps_flutter.dart';

import '../core/constants.dart';
import '../models/assessment_models.dart';
import '../services/map_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({required this.facility, super.key});

  final Facility facility;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final MapService _mapService = MapService();
  GemMapController? _mapController;
  Route? _route;
  bool _mapReady = false;
  bool _verifyingAuthorization = false;
  bool _downloading = false;
  bool _calculating = false;
  bool _navigating = false;
  int _downloadProgress = 0;
  String? _offlineMapName;
  String? _error;
  String? _instruction;
  double? _distanceKm;
  int? _etaMinutes;
  GemError? _authorizationStatus;

  bool get _hasToken => AppConstants.magicLaneApiToken.trim().isNotEmpty;
  bool get _offlineMapReady => _offlineMapName != null;

  @override
  void dispose() {
    if (_navigating) NavigationService.cancelNavigation();
    super.dispose();
  }

  void _onMapCreated(GemMapController controller) {
    _mapController = controller;
    controller.centerOnArea(MapService.keralaBounds);
    setState(() => _mapReady = true);
    _refreshInstalledMap();
    unawaited(_verifyAuthorization());
  }

  Future<GemError> _verifyAuthorization() async {
    if (_verifyingAuthorization) {
      return _authorizationStatus ?? GemError.couldNotStart;
    }
    setState(() => _verifyingAuthorization = true);
    final completer = Completer<GemError>();
    SdkSettings.verifyAppAuthorization(AppConstants.magicLaneApiToken, (
      status,
    ) {
      if (!completer.isCompleted) completer.complete(status);
    });

    GemError status;
    try {
      status = await completer.future.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      status = GemError.networkTimeout;
    }
    if (mounted) {
      setState(() {
        _authorizationStatus = status;
        _verifyingAuthorization = false;
        _error = status == GemError.success
            ? null
            : _authorizationErrorMessage(status);
      });
    }
    return status;
  }

  String _authorizationErrorMessage(GemError status) {
    switch (status) {
      case GemError.invalidInput:
        return 'Magic Lane rejected this token as invalid. Copy the Project '
            'API Key from the Magic Lane developer portal into config.json.';
      case GemError.expired:
        return 'The Magic Lane Project API Key has expired. Generate a new '
            'key in the developer portal and rebuild the app.';
      case GemError.accessDenied:
      case GemError.activation:
        return 'This Magic Lane Project API Key is not authorized for the SDK.';
      case GemError.noConnection:
      case GemError.connectionRequired:
      case GemError.connection:
      case GemError.networkFailed:
      case GemError.networkTimeout:
      case GemError.networkCouldntResolveHost:
        return 'Connect the phone to the internet for the one-time Magic Lane '
            'authorization check and Kerala map download.';
      default:
        return 'Magic Lane authorization failed: $status';
    }
  }

  void _refreshInstalledMap() {
    try {
      final maps = _mapService.installedKeralaMaps();
      if (!mounted) return;
      setState(() {
        _offlineMapName = maps.isEmpty ? null : maps.first.name;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not inspect downloaded maps: $error');
    }
  }

  Future<void> _downloadKeralaMap() async {
    if (!_mapReady || _downloading) return;
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _error = null;
    });
    try {
      final authorization = await _verifyAuthorization();
      if (authorization != GemError.success) return;
      final candidates = await _mapService.availableKeralaMaps();
      if (!mounted) return;
      if (candidates.isEmpty) {
        throw const MapServiceException(
          'Magic Lane did not return an Indian road-map package covering Kerala.',
        );
      }
      final selected = await _selectMapPackage(candidates);
      if (!mounted || selected == null) return;
      if (selected.isCompleted) {
        setState(() => _offlineMapName = selected.name);
        return;
      }

      final completed = Completer<GemError>();
      selected.asyncDownload(
        (error) {
          if (!completed.isCompleted) completed.complete(error);
        },
        onProgress: (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
      );
      final result = await completed.future;
      if (result != GemError.success) {
        throw MapServiceException('Map download failed: $result');
      }
      if (!mounted) return;
      setState(() {
        _offlineMapName = selected.name;
        _downloadProgress = 100;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<ContentStoreItem?> _selectMapPackage(
    List<ContentStoreItem> candidates,
  ) {
    if (candidates.length == 1) return Future.value(candidates.first);
    return showModalBottomSheet<ContentStoreItem>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Download offline road map',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                'These packages intersect Kerala. Prefer the Kerala-only package when available.',
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  final item = candidates[index];
                  return ListTile(
                    leading: Icon(
                      item.isCompleted
                          ? Icons.download_done
                          : Icons.download_outlined,
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.chapterName.isEmpty ? 'India' : item.chapterName} • ${_formatBytes(item.totalSize)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _calculateRoute() async {
    final controller = _mapController;
    if (controller == null || _calculating) return;
    if (!_offlineMapReady) {
      setState(() {
        _error =
            'Download the Kerala road map before calculating an offline route.';
      });
      return;
    }

    setState(() {
      _calculating = true;
      _error = null;
      _instruction = 'Getting your GPS location…';
    });
    try {
      final start = await _mapService.currentCoordinates();
      if (!mounted) return;
      setState(() => _instruction = 'Calculating locally on this phone…');
      final route = await _mapService.calculateOfflineRoute(
        start: start,
        destination: Coordinates.fromLatLong(
          widget.facility.latitude,
          widget.facility.longitude,
        ),
      );
      if (!mounted) return;
      final info = route.getTimeDistance();
      controller.preferences.routes.clear();
      controller.preferences.routes.add(route, true, autoGenerateLabel: true);
      controller.centerOnRoute(route);
      setState(() {
        _route = route;
        _distanceKm = info.totalDistanceM / 1000;
        _etaMinutes = (info.totalTimeS / 60).ceil();
        _instruction = 'Route calculated entirely from downloaded map data.';
      });
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = 'GPS timed out. Move outdoors and try again.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  void _startNavigation() {
    final route = _route;
    final controller = _mapController;
    if (route == null || controller == null) return;

    final positionError = PositionService.setLiveDataSource();
    if (positionError != GemError.success && positionError != GemError.exist) {
      setState(() => _error = 'Could not start GPS: $positionError');
      return;
    }

    final task = NavigationService.startNavigation(
      route,
      onNavigationStarted: () {
        if (mounted) setState(() => _navigating = true);
      },
      onNavigationInstruction: (instruction, events) {
        if (!mounted) return;
        final remaining = instruction.remainingTravelTimeDistance;
        setState(() {
          _instruction = instruction.nextTurnInstruction;
          _distanceKm = remaining.totalDistanceM / 1000;
          _etaMinutes = (remaining.totalTimeS / 60).ceil();
        });
      },
      onDestinationReached: (_) {
        if (!mounted) return;
        setState(() {
          _navigating = false;
          _instruction = 'You have reached ${widget.facility.name}.';
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _navigating = false;
          _error = 'Navigation stopped: $error';
        });
      },
    );
    if (task == null) {
      setState(() => _error = 'Navigation could not be started.');
      return;
    }
    setState(() {
      _navigating = true;
      _error = null;
    });
    controller.startFollowingPosition();
  }

  void _stopNavigation() {
    NavigationService.cancelNavigation();
    setState(() {
      _navigating = false;
      _instruction = 'Navigation stopped. The offline route remains available.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route to Hospital'),
        actions: [
          IconButton(
            onPressed:
                _hasToken &&
                    _mapReady &&
                    !_downloading &&
                    !_verifyingAuthorization
                ? _downloadKeralaMap
                : null,
            tooltip: _offlineMapReady
                ? 'Offline map: $_offlineMapName'
                : 'Download Kerala map',
            icon: _downloading
                ? SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: _downloadProgress == 0
                          ? null
                          : _downloadProgress / 100,
                    ),
                  )
                : Icon(
                    _offlineMapReady
                        ? Icons.offline_pin_outlined
                        : Icons.download_for_offline_outlined,
                  ),
          ),
        ],
      ),
      body: !_hasToken
          ? const _MissingTokenView()
          : Stack(
              children: [
                Positioned.fill(
                  child: GemMap(
                    appAuthorization: AppConstants.magicLaneApiToken,
                    onMapCreated: _onMapCreated,
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _OfflineBadge(
                    ready: _offlineMapReady,
                    mapName: _offlineMapName,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 18,
                  child: _buildRouteCard(),
                ),
              ],
            ),
    );
  }

  Widget _buildRouteCard() {
    final distance = _distanceKm ?? widget.facility.distanceKm;
    final eta = _etaMinutes ?? widget.facility.etaMinutes;
    return SectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.facility.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          Text('${distance.toStringAsFixed(1)} km  •  ~$eta min'),
          if (_instruction != null) ...[
            const SizedBox(height: 8),
            Text(
              _instruction!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 10),
          if (!_offlineMapReady)
            PrimaryButton(
              label: _verifyingAuthorization
                  ? 'Checking Map Authorization…'
                  : _downloading
                  ? 'Downloading $_downloadProgress%'
                  : _authorizationStatus != null &&
                        _authorizationStatus != GemError.success
                  ? 'Retry Map Connection'
                  : 'Download Kerala Map',
              icon: Icons.download_for_offline_outlined,
              onPressed: _downloading || _verifyingAuthorization || !_mapReady
                  ? null
                  : _downloadKeralaMap,
            )
          else if (_route == null)
            PrimaryButton(
              label: _calculating
                  ? 'Calculating Offline Route…'
                  : 'Calculate Offline Route',
              icon: Icons.route_outlined,
              onPressed: _calculating ? null : _calculateRoute,
            )
          else
            PrimaryButton(
              label: _navigating ? 'Stop Navigation' : 'Start Navigation',
              icon: _navigating ? Icons.stop_circle_outlined : Icons.navigation,
              onPressed: _navigating ? _stopNavigation : _startNavigation,
            ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    final megabytes = bytes / (1024 * 1024);
    return megabytes >= 1024
        ? '${(megabytes / 1024).toStringAsFixed(1)} GB'
        : '${megabytes.toStringAsFixed(0)} MB';
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge({required this.ready, required this.mapName});

  final bool ready;
  final String? mapName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ready ? Icons.offline_pin : Icons.cloud_download_outlined,
              size: 18,
              color: ready ? AppColors.primary : AppColors.urgent,
            ),
            const SizedBox(width: 6),
            Text(
              ready
                  ? '${mapName ?? 'Kerala'} ready offline'
                  : 'Map not downloaded',
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingTokenView extends StatelessWidget {
  const _MissingTokenView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: SectionCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.key_off_outlined, size: 42, color: AppColors.urgent),
              SizedBox(height: 12),
              Text(
                'Magic Lane token missing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                'Add MAGICLANE_API_TOKEN to config.json, then rebuild with '
                '--dart-define-from-file=config.json.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
