// services/map_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

class MapService {
  // Get current location
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    // Get current position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Convert address to coordinates
  static Future<LatLng?> addressToLatLng(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
      return null;
    } catch (e) {
      print('Error converting address to coordinates: $e');
      return null;
    }
  }

  // Convert coordinates to address
  static Future<String?> latLngToAddress(LatLng latLng) async {
    try {
      final places = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (places.isNotEmpty) {
        final place = places.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }
      return null;
    } catch (e) {
      print('Error converting coordinates to address: $e');
      return null;
    }
  }

  // Calculate distance between two points
  static double calculateDistance(LatLng start, LatLng end) {
    const Distance distance = Distance();
    return distance(start, end) / 1000; // Return in kilometers
  }

  // Get route polyline (simplified - in real app you'd use a routing service)
  static List<LatLng> getRoutePoints(LatLng start, LatLng end) {
    // This is a simplified straight line route
    // In production, use a routing service like OSRM, Mapbox, etc.
    return [start, end];
  }
}