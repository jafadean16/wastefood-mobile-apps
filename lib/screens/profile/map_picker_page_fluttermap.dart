import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerPageFlutterMap extends StatefulWidget {
  const MapPickerPageFlutterMap({super.key});

  @override
  State<MapPickerPageFlutterMap> createState() => _MapPickerPageFlutterMapState();
}

class _MapPickerPageFlutterMapState extends State<MapPickerPageFlutterMap> with TickerProviderStateMixin {
  LatLng _initialPosition = const LatLng(-6.200000, 106.816666); // Default Jakarta
  LatLng _selectedPosition = const LatLng(-6.200000, 106.816666);
  bool _locationFetched = false;

  late AnimationController _markerAnimationController;
  late Animation<double> _markerAnimation;

  @override
  void initState() {
    super.initState();
    _initMarkerAnimation();
    _getUserLocation();
  }

  void _initMarkerAnimation() {
    _markerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _markerAnimation = Tween<double>(begin: 0, end: -10)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_markerAnimationController);
  }

  @override
  void dispose() {
    _markerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return; // ✅ penting kalau async

      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _selectedPosition = LatLng(position.latitude, position.longitude);
        _locationFetched = true;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _onTap(LatLng position) {
    setState(() {
      _selectedPosition = position;
      _markerAnimationController.forward(from: 0); // Mainkan animasi marker
    });
  }

  Future<void> _confirmLocation() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Lokasi'),
        content: const Text('Apakah kamu yakin memilih lokasi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yakin'),
          ),
        ],
      ),
    );

    if (!mounted) return; // ✅ tambah ini supaya aman

    if (confirmed == true) {
      Navigator.pop(context, {
        'latitude': _selectedPosition.latitude,
        'longitude': _selectedPosition.longitude,
      });
    }
  }

  void _resetLocation() {
    setState(() {
      _selectedPosition = _initialPosition;
      _markerAnimationController.forward(from: 0); // Mainkan animasi marker
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetLocation,
          ),
        ],
      ),
      body: _locationFetched
          ? FlutterMap(
  options: MapOptions(
    initialCenter: _initialPosition,
    initialZoom: 13.0,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.white, // Tema gelap atau terang
    onTap: (_, point) => _onTap(point),
  ),
  children: [
    TileLayer(
      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
      subdomains: const ['a', 'b', 'c'],
    ),
    MarkerLayer(
      markers: [
        Marker(
          width: 80,
          height: 80,
          point: _selectedPosition,
          child: AnimatedBuilder(
            animation: _markerAnimation,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _markerAnimation.value),
              child: child,
            ),
            child: const Icon(Icons.location_on, size: 40, color: Colors.red),
          ),
        ),
      ],
    ),
  ],
)
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirmLocation,
        label: const Text('Pilih Lokasi'),
        icon: const Icon(Icons.check),
      ),
    );
  }
}
