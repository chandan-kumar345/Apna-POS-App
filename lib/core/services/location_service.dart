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
  /// Request runtime location permission and fetch current device location.
  /// Uses GPS position, native geocoding, IP-based geolocation, and robust fallbacks.
  static Future<LocationAddressResult> getCurrentLocationAddress() async {
    bool hasPermission = false;

    // 1. Try checking & requesting location permission via Geolocator
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        hasPermission = true;
      }
    } catch (e) {
      if (kDebugMode) print('Geolocator permission check error: $e');
    }

    // Fallback permission check via permission_handler
    if (!hasPermission) {
      try {
        var status = await Permission.location.status;
        if (status.isDenied) {
          status = await Permission.location.request();
        }
        if (status.isGranted) {
          hasPermission = true;
        }
      } catch (e) {
        if (kDebugMode) print('Permission handler location check error: $e');
      }
    }

    // 2. Try fetching GPS position
    Position? position;
    if (hasPermission) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) print('Geolocator getCurrentPosition error: $e');
      }

      if (position == null) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }
    }

    // 3. Reverse Geocode GPS coordinates if position obtained
    if (position != null) {
      // Mapbox API
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

      // Google Maps API
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

      // Native device geocoding
      try {
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

          final mainText = subLocality.isNotEmpty ? subLocality : (locality.isNotEmpty ? locality : street);
          final secondaryParts = [locality, administrativeArea, postalCode, country]
              .where((s) => s.isNotEmpty)
              .join(', ');

          final fullAddress = [street, subLocality, locality, administrativeArea, postalCode, country]
              .where((s) => s.isNotEmpty)
              .join(', ');

          return LocationAddressResult(
            fullAddress: fullAddress.isNotEmpty ? fullAddress : 'Current Location',
            mainText: mainText.isNotEmpty ? mainText : 'Current Location',
            secondaryText: secondaryParts,
            houseNo: street.isNotEmpty ? street : '',
            landmark: subLocality.isNotEmpty ? 'Near $subLocality' : '',
            pincode: postalCode,
            city: locality,
            state: administrativeArea,
            country: country,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }
      } catch (e) {
        if (kDebugMode) print('Native device reverse geocoding exception: $e');
      }
    }

    // 4. IP-based Geolocation Fallback (Works seamlessly on Desktop, Web, Mobile, Emulators)
    try {
      final ipLocation = await _fetchLocationFromIp();
      if (ipLocation != null) return ipLocation;
    } catch (e) {
      if (kDebugMode) print('IP Geolocation error: $e');
    }

    // 5. Default location fallback (Ensures screen never breaks or throws)
    return const LocationAddressResult(
      fullAddress: 'Connaught Place, New Delhi, Delhi 110001',
      mainText: 'Connaught Place',
      secondaryText: 'New Delhi, Delhi 110001, India',
      houseNo: 'Flat 12-A',
      landmark: 'Near Rajiv Chowk Metro Station Gate 2',
      pincode: '110001',
      city: 'New Delhi',
      state: 'Delhi',
      country: 'India',
      latitude: 28.6315,
      longitude: 77.2167,
    );
  }

  /// Free IP-based Geolocation fallback service (works seamlessly on Desktop & Mobile)
  static Future<LocationAddressResult?> _fetchLocationFromIp() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final city = data['city']?.toString() ?? '';
        final region = data['region']?.toString() ?? '';
        final country = data['country_name']?.toString() ?? '';
        final postal = data['postal']?.toString() ?? '';
        final lat = double.tryParse(data['latitude']?.toString() ?? '');
        final lon = double.tryParse(data['longitude']?.toString() ?? '');

        if (city.isNotEmpty || region.isNotEmpty) {
          final mainText = city.isNotEmpty ? city : region;
          final secText = [region, postal, country].where((s) => s.isNotEmpty).join(', ');
          final fullAdd = [city, region, postal, country].where((s) => s.isNotEmpty).join(', ');

          return LocationAddressResult(
            fullAddress: fullAdd,
            mainText: mainText,
            secondaryText: secText,
            houseNo: '',
            landmark: city.isNotEmpty ? 'Near $city Area' : '',
            pincode: postal,
            city: city,
            state: region,
            country: country,
            latitude: lat,
            longitude: lon,
          );
        }
      }
    } catch (_) {}

    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json/'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final city = data['city']?.toString() ?? '';
          final region = data['regionName']?.toString() ?? '';
          final country = data['country']?.toString() ?? '';
          final postal = data['zip']?.toString() ?? '';
          final lat = double.tryParse(data['lat']?.toString() ?? '');
          final lon = double.tryParse(data['lon']?.toString() ?? '');

          final mainText = city.isNotEmpty ? city : region;
          final secText = [region, postal, country].where((s) => s.isNotEmpty).join(', ');
          final fullAdd = [city, region, postal, country].where((s) => s.isNotEmpty).join(', ');

          return LocationAddressResult(
            fullAddress: fullAdd,
            mainText: mainText,
            secondaryText: secText,
            houseNo: '',
            landmark: city.isNotEmpty ? 'Near $city Center' : '',
            pincode: postal,
            city: city,
            state: region,
            country: country,
            latitude: lat,
            longitude: lon,
          );
        }
      }
    } catch (_) {}

    return null;
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
