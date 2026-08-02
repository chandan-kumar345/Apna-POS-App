import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class LocationAddressResult {
  final String fullAddress;
  final String mainText;
  final String secondaryText;
  final String houseNo;
  final String landmark;
  final String pincode;
  final String city;
  final String state;
  final String country;
  final double? latitude;
  final double? longitude;

  const LocationAddressResult({
    required this.fullAddress,
    required this.mainText,
    required this.secondaryText,
    required this.houseNo,
    required this.landmark,
    required this.pincode,
    required this.city,
    required this.state,
    required this.country,
    this.latitude,
    this.longitude,
  });
}

class LocationService {
  /// Mapbox API Key provided by user
  static String mapboxApiKey =
      ''; // TODO: Set your Mapbox token here (do NOT commit real tokens)

  /// Option to set your Google Maps API key if needed
  static String googleMapsApiKey = '';

  /// Request runtime location permission and fetch current device location.
  /// Returns [LocationAddressResult] with full address, city, landmark, pincode & coordinates.
  static Future<LocationAddressResult> getCurrentLocationAddress() async {
    // 1. Check & Request Location Permission using permission_handler
    var permissionStatus = await Permission.location.status;
    if (permissionStatus.isDenied) {
      permissionStatus = await Permission.location.request();
    }

    if (permissionStatus.isPermanentlyDenied) {
      await openAppSettings();
      throw Exception(
        'Location permission is permanently denied. Please allow location access in your device settings.',
      );
    }

    if (!permissionStatus.isGranted) {
      throw Exception('Location permission was denied by user.');
    }

    // 2. Ensure Location Service / GPS toggle is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services (GPS) are disabled on your device.');
    }

    // 3. Fetch exact GPS latitude and longitude
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );

    // 4. Reverse Geocode GPS coordinates with Mapbox API
    if (mapboxApiKey.isNotEmpty) {
      try {
        final mapboxAddress = await _reverseGeocodeWithMapbox(
          position.latitude,
          position.longitude,
        );
        if (mapboxAddress != null) return mapboxAddress;
      } catch (e) {
        if (kDebugMode) print('Mapbox Reverse Geocode error: $e');
      }
    }

    // Reverse Geocode GPS coordinates with Google Maps API
    if (googleMapsApiKey.isNotEmpty) {
      try {
        final googleAddress = await _reverseGeocodeWithGoogle(
          position.latitude,
          position.longitude,
        );
        if (googleAddress != null) return googleAddress;
      } catch (e) {
        if (kDebugMode) print('Google Reverse Geocode error: $e');
      }
    }

    // Fallback to native device geocoding
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      final place = placemarks.first;

      final street = place.street ?? place.subThoroughfare ?? '';
      final subLocality = place.subLocality ?? place.name ?? '';
      final locality = place.locality ?? place.subAdministrativeArea ?? '';
      final administrativeArea = place.administrativeArea ?? '';
      final postalCode = place.postalCode ?? '';
      final country = place.country ?? '';

      final mainText = subLocality.isNotEmpty ? subLocality : street;
      final secondaryParts = [locality, administrativeArea, postalCode, country]
          .where((s) => s.isNotEmpty)
          .join(', ');

      final fullAddress = [street, subLocality, locality, administrativeArea, postalCode, country]
          .where((s) => s.isNotEmpty)
          .join(', ');

      return LocationAddressResult(
        fullAddress: fullAddress,
        mainText: mainText.isNotEmpty ? mainText : locality,
        secondaryText: secondaryParts,
        houseNo: street.isNotEmpty ? street : 'Block A',
        landmark: subLocality.isNotEmpty ? 'Near $subLocality' : 'Main Road',
        pincode: postalCode,
        city: locality,
        state: administrativeArea,
        country: country,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }

    throw Exception('Unable to convert GPS coordinates into address.');
  }

  /// Search address suggestions using Mapbox / Google Places Autocomplete API.
  /// Falls back to native device geocoding.
  static Future<List<LocationAddressResult>> fetchAddressSuggestions(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // 1. Mapbox Geocoding Places Autocomplete Search API
    if (mapboxApiKey.isNotEmpty) {
      try {
        final mapboxResults = await _fetchSuggestionsWithMapbox(cleanQuery);
        if (mapboxResults.isNotEmpty) return mapboxResults;
      } catch (e) {
        if (kDebugMode) print('Mapbox Places API Exception: $e');
      }
    }

    // 2. Google Places API
    if (googleMapsApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(cleanQuery)}&key=$googleMapsApiKey',
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && data['predictions'] != null) {
            final List predictions = data['predictions'];
            return predictions.map((pred) {
              final structured = pred['structured_formatting'] ?? {};
              return LocationAddressResult(
                fullAddress: pred['description'] ?? '',
                mainText: structured['main_text'] ?? pred['description'] ?? '',
                secondaryText: structured['secondary_text'] ?? '',
                houseNo: '',
                landmark: '',
                pincode: '',
                city: '',
                state: '',
                country: '',
              );
            }).toList();
          }
        }
      } catch (e) {
        if (kDebugMode) print('Google Places API Exception: $e');
      }
    }

    // 3. Fallback: Native Flutter Geocoding API
    try {
      List<Location> locations = await locationFromAddress(cleanQuery);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        List<Placemark> placemarks = await placemarkFromCoordinates(
          loc.latitude,
          loc.longitude,
        );

        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final mainText = p.subLocality ?? p.street ?? cleanQuery;
          final secText = [p.locality, p.administrativeArea, p.postalCode]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');

          final fullAdd = [p.street, p.subLocality, p.locality, p.administrativeArea, p.postalCode]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');

          return [
            LocationAddressResult(
              fullAddress: fullAdd.isNotEmpty ? fullAdd : cleanQuery,
              mainText: mainText,
              secondaryText: secText,
              houseNo: p.street ?? '',
              landmark: p.subLocality != null ? 'Near ${p.subLocality}' : '',
              pincode: p.postalCode ?? '',
              city: p.locality ?? '',
              state: p.administrativeArea ?? '',
              country: p.country ?? '',
              latitude: loc.latitude,
              longitude: loc.longitude,
            ),
          ];
        }
      }
    } catch (_) {
      // Ignored for fallback
    }

    return [];
  }

  /// Reverse geocode coordinates using Mapbox API endpoint.
  static Future<LocationAddressResult?> _reverseGeocodeWithMapbox(
    double lat,
    double lng,
  ) async {
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=$mapboxApiKey',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['features'] as List?;
      if (features != null && features.isNotEmpty) {
        final top = features.first;
        final fullAddress = top['place_name'] ?? '';
        final mainText = top['text'] ?? '';

        String houseNo = top['address'] ?? '';
        String pincode = '';
        String city = '';
        String state = '';
        String country = '';

        final contexts = top['context'] as List? ?? [];
        for (var item in contexts) {
          final id = item['id'] as String? ?? '';
          if (id.startsWith('postcode')) pincode = item['text'] ?? '';
          if (id.startsWith('place') || id.startsWith('locality')) city = item['text'] ?? '';
          if (id.startsWith('region')) state = item['text'] ?? '';
          if (id.startsWith('country')) country = item['text'] ?? '';
        }

        final secondaryText = [city, state, pincode, country].where((s) => s.isNotEmpty).join(', ');

        return LocationAddressResult(
          fullAddress: fullAddress,
          mainText: mainText.isNotEmpty ? mainText : (city.isNotEmpty ? city : 'Current Location'),
          secondaryText: secondaryText,
          houseNo: houseNo.isNotEmpty ? houseNo : 'Building 1',
          landmark: mainText.isNotEmpty ? 'Near $mainText' : '',
          pincode: pincode,
          city: city,
          state: state,
          country: country,
          latitude: lat,
          longitude: lng,
        );
      }
    }
    return null;
  }

  /// Search address suggestions using Mapbox Geocoding Places API.
  static Future<List<LocationAddressResult>> _fetchSuggestionsWithMapbox(String cleanQuery) async {
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(cleanQuery)}.json?access_token=$mapboxApiKey&autocomplete=true',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['features'] as List?;
      if (features != null && features.isNotEmpty) {
        return features.map((feat) {
          final fullAddress = feat['place_name'] ?? '';
          final mainText = feat['text'] ?? '';
          final center = feat['center'] as List?;
          double? lng = center != null && center.isNotEmpty ? (center[0] as num).toDouble() : null;
          double? lat = center != null && center.length > 1 ? (center[1] as num).toDouble() : null;

          String houseNo = feat['address'] ?? '';
          String pincode = '';
          String city = '';
          String state = '';
          String country = '';

          final contexts = feat['context'] as List? ?? [];
          for (var item in contexts) {
            final id = item['id'] as String? ?? '';
            if (id.startsWith('postcode')) pincode = item['text'] ?? '';
            if (id.startsWith('place') || id.startsWith('locality')) city = item['text'] ?? '';
            if (id.startsWith('region')) state = item['text'] ?? '';
            if (id.startsWith('country')) country = item['text'] ?? '';
          }

          final secText = [city, state, pincode, country].where((s) => s.isNotEmpty).join(', ');

          return LocationAddressResult(
            fullAddress: fullAddress,
            mainText: mainText.isNotEmpty ? mainText : fullAddress,
            secondaryText: secText.isNotEmpty ? secText : fullAddress,
            houseNo: houseNo,
            landmark: mainText.isNotEmpty ? 'Near $mainText' : '',
            pincode: pincode,
            city: city,
            state: state,
            country: country,
            latitude: lat,
            longitude: lng,
          );
        }).toList();
      }
    }
    return [];
  }

  /// Reverse geocode coordinates using Google Geocoding API HTTP endpoint.
  static Future<LocationAddressResult?> _reverseGeocodeWithGoogle(
    double lat,
    double lng,
  ) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$googleMapsApiKey',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
        final result = data['results'][0];
        final formattedAddress = result['formatted_address'] ?? '';
        final components = result['address_components'] as List? ?? [];

        String houseNo = '';
        String route = '';
        String sublocality = '';
        String city = '';
        String state = '';
        String pincode = '';
        String country = '';

        for (var comp in components) {
          final types = comp['types'] as List? ?? [];
          if (types.contains('street_number')) houseNo = comp['long_name'] ?? '';
          if (types.contains('route')) route = comp['long_name'] ?? '';
          if (types.contains('sublocality') || types.contains('sublocality_level_1')) {
            sublocality = comp['long_name'] ?? '';
          }
          if (types.contains('locality')) city = comp['long_name'] ?? '';
          if (types.contains('administrative_area_level_1')) state = comp['long_name'] ?? '';
          if (types.contains('postal_code')) pincode = comp['long_name'] ?? '';
          if (types.contains('country')) country = comp['long_name'] ?? '';
        }

        final streetCombined = [houseNo, route].where((s) => s.isNotEmpty).join(' ');

        return LocationAddressResult(
          fullAddress: formattedAddress,
          mainText: sublocality.isNotEmpty ? sublocality : (streetCombined.isNotEmpty ? streetCombined : city),
          secondaryText: [city, state, pincode].where((s) => s.isNotEmpty).join(', '),
          houseNo: streetCombined.isNotEmpty ? streetCombined : 'Building 1',
          landmark: sublocality.isNotEmpty ? 'Near $sublocality' : '',
          pincode: pincode,
          city: city,
          state: state,
          country: country,
          latitude: lat,
          longitude: lng,
        );
      }
    }
    return null;
  }
}
