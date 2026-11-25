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
  final String placeId;

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
    this.placeId = '',
  });
}

class LocationService {
  /// Mapbox API Key provided by user
  static String mapboxApiKey =
      ''; // TODO: Set your Mapbox token here (do NOT commit real tokens)

  /// Option to set your Google Maps API key (can also be passed via --dart-define=GOOGLE_MAPS_API_KEY=...)
  static String googleMapsApiKey = const String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  @visibleForTesting
  static Future<List<LocationAddressResult>> Function(String query)?
      debugAddressSearchOverride;
  @visibleForTesting
  static Future<LocationAddressResult> Function()? debugCurrentLocationOverride;
  @visibleForTesting
  static Future<LocationAddressResult?> Function(LocationAddressResult result)?
      debugResolveDetailsOverride;
  @visibleForTesting
  static Future<LocationAddressResult?> Function(String pinCode)?
      debugPincodeLookupOverride;

  /// Extracts a valid 6-digit Indian PIN code if present in [text].
  static String extractPinCode(String text) {
    final match = RegExp(r'\b([1-9][0-9]{5})\b').firstMatch(text);
    return match?.group(1) ?? '';
  }

  /// Request runtime location permission and fetch current device location.
  /// Returns [LocationAddressResult] with full address, city, landmark, pincode & coordinates.
  /// Uses GPS position, native geocoding, Nominatim reverse geocoding, IP-based geolocation, and fallbacks.
  static Future<LocationAddressResult> getCurrentLocationAddress() async {
    final override = debugCurrentLocationOverride;
    if (override != null) {
      return override();
    }
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

      // Native device geocoding (skip on web where native geocoding isn't supported)
      LocationAddressResult? nativeResult;
      if (!kIsWeb) {
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

            nativeResult = LocationAddressResult(
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
            if (postalCode.isNotEmpty) return nativeResult;
          }
        } catch (e) {
          if (kDebugMode) print('Native device reverse geocoding exception: $e');
        }
      }

      // OpenStreetMap Nominatim reverse geocoding (works across Android, Web, Desktop)
      try {
        final nominatimResult = await _reverseGeocodeWithNominatim(
          position.latitude,
          position.longitude,
        );
        if (nominatimResult != null) return nominatimResult;
      } catch (e) {
        if (kDebugMode) print('Nominatim Reverse Geocode error: $e');
      }

      if (nativeResult != null) return nativeResult;
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

  /// Search address suggestions using Google Places, Mapbox, or open geocoding APIs.
  /// Falls back to native device geocoding when available.
  static Future<List<LocationAddressResult>> fetchAddressSuggestions(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final override = debugAddressSearchOverride;
    if (override != null) {
      return override(cleanQuery);
    }

    // 1. Mapbox Geocoding Places Autocomplete Search API
    if (mapboxApiKey.isNotEmpty) {
      try {
        final mapboxResults = await _fetchSuggestionsWithMapbox(cleanQuery);
        if (mapboxResults.isNotEmpty) return mapboxResults;
      } catch (e) {
        if (kDebugMode) print('Mapbox Places API Exception: $e');
      }
    }

    // 2. Google Places Autocomplete API
    if (googleMapsApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(cleanQuery)}&components=country:in&key=$googleMapsApiKey',
        );

        final response = await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && data['predictions'] != null) {
            final List predictions = data['predictions'];
            return predictions.map((pred) {
              final structured = pred['structured_formatting'] ?? {};
              final desc = pred['description']?.toString() ?? '';
              return LocationAddressResult(
                fullAddress: desc,
                mainText: structured['main_text']?.toString() ?? desc,
                secondaryText: structured['secondary_text']?.toString() ?? '',
                houseNo: '',
                landmark: '',
                pincode: extractPinCode(desc),
                city: '',
                state: '',
                country: '',
                placeId: pred['place_id']?.toString() ?? '',
              );
            }).toList();
          }
        }
      } catch (e) {
        if (kDebugMode) print('Google Places API Exception: $e');
      }
    }

    // 3. Cross-platform HTTP Geocoding (Nominatim + Photon - works on Android, Web & Desktop)
    try {
      final results = await Future.wait([
        _fetchSuggestionsWithNominatim(cleanQuery),
        _fetchSuggestionsWithPhoton(cleanQuery),
      ]);
      final merged = <LocationAddressResult>[];
      final seen = <String>{};
      for (final batch in results) {
        for (final item in batch) {
          final key = item.fullAddress.trim().toLowerCase();
          if (key.isNotEmpty && seen.add(key)) {
            merged.add(item);
          }
        }
      }
      if (merged.isNotEmpty) {
        merged.sort((a, b) {
          final aHasPin = a.pincode.isNotEmpty ? 0 : 1;
          final bHasPin = b.pincode.isNotEmpty ? 0 : 1;
          return aHasPin.compareTo(bHasPin);
        });
        return merged.take(6).toList();
      }
    } catch (e) {
      if (kDebugMode) print('HTTP address autocomplete exception: $e');
    }

    // 4. Fallback: Native Flutter Geocoding API
    if (!kIsWeb) {
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
    }

    return [];
  }

  /// Resolves missing structured fields (such as Pincode, landmark, coordinates)
  /// when a user selects an autocomplete suggestion.
  static Future<LocationAddressResult> resolveSuggestionDetails(
    LocationAddressResult suggestion,
  ) async {
    final override = debugResolveDetailsOverride;
    if (override != null) {
      final resolved = await override(suggestion);
      if (resolved != null) return resolved;
    }

    // 1. Google Place Details lookup when a Google Place ID is present
    if (suggestion.placeId.isNotEmpty && googleMapsApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=${Uri.encodeComponent(suggestion.placeId)}&fields=address_component,formatted_address,geometry,name&key=$googleMapsApiKey',
        );
        final response = await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && data['result'] is Map) {
            final result = Map<String, dynamic>.from(data['result'] as Map);
            final parsed = _parseGooglePlaceResult(result);
            if (parsed != null) return parsed;
          }
        }
      } catch (e) {
        if (kDebugMode) print('Google Place Details Exception: $e');
      }
    }

    // 2. Fill missing pincode via reverse geocode if coordinates exist
    if (suggestion.pincode.isEmpty &&
        suggestion.latitude != null &&
        suggestion.longitude != null) {
      try {
        final rev = await _reverseGeocodeWithNominatim(
          suggestion.latitude!,
          suggestion.longitude!,
        );
        if (rev != null && rev.pincode.isNotEmpty) {
          return LocationAddressResult(
            fullAddress: suggestion.fullAddress.isNotEmpty
                ? suggestion.fullAddress
                : rev.fullAddress,
            mainText: suggestion.mainText.isNotEmpty ? suggestion.mainText : rev.mainText,
            secondaryText: suggestion.secondaryText.isNotEmpty
                ? suggestion.secondaryText
                : rev.secondaryText,
            houseNo: suggestion.houseNo.isNotEmpty ? suggestion.houseNo : rev.houseNo,
            landmark: suggestion.landmark.isNotEmpty ? suggestion.landmark : rev.landmark,
            pincode: rev.pincode,
            city: suggestion.city.isNotEmpty ? suggestion.city : rev.city,
            state: suggestion.state.isNotEmpty ? suggestion.state : rev.state,
            country: suggestion.country.isNotEmpty ? suggestion.country : rev.country,
            latitude: suggestion.latitude,
            longitude: suggestion.longitude,
            placeId: suggestion.placeId,
          );
        }
      } catch (_) {}
    }

    final fallbackPin = suggestion.pincode.isNotEmpty
        ? suggestion.pincode
        : extractPinCode(suggestion.fullAddress);
    if (fallbackPin != suggestion.pincode) {
      return LocationAddressResult(
        fullAddress: suggestion.fullAddress,
        mainText: suggestion.mainText,
        secondaryText: suggestion.secondaryText,
        houseNo: suggestion.houseNo,
        landmark: suggestion.landmark,
        pincode: fallbackPin,
        city: suggestion.city,
        state: suggestion.state,
        country: suggestion.country,
        latitude: suggestion.latitude,
        longitude: suggestion.longitude,
        placeId: suggestion.placeId,
      );
    }

    return suggestion;
  }

  /// Looks up locality, city and state for a 6-digit Indian PIN code.
  static Future<LocationAddressResult?> lookupPincode(String pinCode) async {
    final pin = pinCode.trim();
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(pin)) return null;

    final override = debugPincodeLookupOverride;
    if (override != null) {
      return override(pin);
    }

    try {
      final response = await http
          .get(Uri.parse('https://api.postalpincode.in/pincode/$pin'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          final first = decoded.first;
          if (first is Map &&
              first['Status'] == 'Success' &&
              first['PostOffice'] is List &&
              (first['PostOffice'] as List).isNotEmpty) {
            final po = Map<String, dynamic>.from(
              (first['PostOffice'] as List).first as Map,
            );
            final area = po['Name']?.toString().trim() ?? '';
            final block = po['Block']?.toString().trim() ?? '';
            final district = po['District']?.toString().trim() ?? '';
            final state = po['State']?.toString().trim() ?? '';
            final country = po['Country']?.toString().trim() ?? 'India';
            final city = district.isNotEmpty ? district : block;
            final full = [area, city, state].where((s) => s.isNotEmpty).join(', ');
            return LocationAddressResult(
              fullAddress: full.isNotEmpty ? full : pin,
              mainText: area.isNotEmpty ? area : city,
              secondaryText: [city, state].where((s) => s.isNotEmpty).join(', '),
              houseNo: '',
              landmark: area.isNotEmpty ? 'Near $area' : '',
              pincode: pin,
              city: city,
              state: state,
              country: country,
            );
          }
        }
      }
    } catch (_) {}

    try {
      final headers = <String, String>{
        if (!kIsWeb) 'User-Agent': 'ApnaPOS-Storefront/1.0',
      };
      final response = await http
          .get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/search?postalcode=$pin&format=jsonv2&addressdetails=1&limit=1',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          final parsed = _parseNominatimMap(
            Map<String, dynamic>.from(decoded.first as Map),
            fallbackPin: pin,
          );
          if (parsed != null) return parsed;
        }
      }
    } catch (_) {}

    return null;
  }

  static Future<List<LocationAddressResult>> _fetchSuggestionsWithNominatim(
    String cleanQuery,
  ) async {
    try {
      final headers = <String, String>{
        if (!kIsWeb) 'User-Agent': 'ApnaPOS-Storefront/1.0',
      };
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=jsonv2&addressdetails=1&limit=6',
      );
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data
              .whereType<Map>()
              .map((m) => _parseNominatimMap(Map<String, dynamic>.from(m)))
              .whereType<LocationAddressResult>()
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<LocationAddressResult?> _reverseGeocodeWithNominatim(
    double lat,
    double lng,
  ) async {
    try {
      final headers = <String, String>{
        if (!kIsWeb) 'User-Agent': 'ApnaPOS-Storefront/1.0',
      };
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=jsonv2&addressdetails=1',
      );
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map) {
          return _parseNominatimMap(Map<String, dynamic>.from(data));
        }
      }
    } catch (_) {}
    return null;
  }

  static LocationAddressResult? _parseNominatimMap(
    Map<String, dynamic> item, {
    String fallbackPin = '',
  }) {
    final addr = item['address'] is Map
        ? Map<String, dynamic>.from(item['address'] as Map)
        : <String, dynamic>{};
    final houseNumber = addr['house_number']?.toString().trim() ?? '';
    final road = addr['road']?.toString().trim() ??
        addr['pedestrian']?.toString().trim() ??
        '';
    final suburb = addr['neighbourhood']?.toString().trim() ??
        addr['suburb']?.toString().trim() ??
        addr['city_district']?.toString().trim() ??
        '';
    final city = addr['city']?.toString().trim() ??
        addr['town']?.toString().trim() ??
        addr['village']?.toString().trim() ??
        addr['state_district']?.toString().trim() ??
        '';
    final state = addr['state']?.toString().trim() ?? '';
    final country = addr['country']?.toString().trim() ?? '';
    final rawPostal = addr['postcode']?.toString().trim() ?? '';
    final displayName = item['display_name']?.toString().trim() ?? '';
    final pincode = extractPinCode(rawPostal).isNotEmpty
        ? extractPinCode(rawPostal)
        : (rawPostal.isNotEmpty
            ? rawPostal
            : (fallbackPin.isNotEmpty ? fallbackPin : extractPinCode(displayName)));

    final streetPart = [houseNumber, road].where((s) => s.isNotEmpty).join(' ');
    final formattedParts = [
      if (streetPart.isNotEmpty) streetPart,
      if (suburb.isNotEmpty) suburb,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
    ];
    final fullAddress = formattedParts.isNotEmpty
        ? formattedParts.join(', ')
        : displayName;
    if (fullAddress.isEmpty) return null;

    final mainText = [streetPart, suburb, city]
        .firstWhere((s) => s.isNotEmpty, orElse: () => fullAddress);
    final secondaryText = [city, state, pincode]
        .where((s) => s.isNotEmpty && s != mainText)
        .join(', ');

    return LocationAddressResult(
      fullAddress: fullAddress,
      mainText: mainText,
      secondaryText: secondaryText.isNotEmpty ? secondaryText : displayName,
      houseNo: streetPart,
      landmark: suburb.isNotEmpty ? 'Near $suburb' : '',
      pincode: pincode,
      city: city,
      state: state,
      country: country,
      latitude: double.tryParse(item['lat']?.toString() ?? ''),
      longitude: double.tryParse(item['lon']?.toString() ?? ''),
    );
  }

  static Future<List<LocationAddressResult>> _fetchSuggestionsWithPhoton(
    String cleanQuery,
  ) async {
    try {
      final url = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&limit=6&lat=22.9734&lon=78.6569',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data is Map ? data['features'] as List? : null;
        if (features != null) {
          return features.whereType<Map>().map((rawFeat) {
            final feat = Map<String, dynamic>.from(rawFeat);
            final props = feat['properties'] is Map
                ? Map<String, dynamic>.from(feat['properties'] as Map)
                : <String, dynamic>{};
            final geom = feat['geometry'] is Map
                ? Map<String, dynamic>.from(feat['geometry'] as Map)
                : <String, dynamic>{};
            final coords = geom['coordinates'] as List?;
            final lng = coords != null && coords.isNotEmpty
                ? (coords[0] as num?)?.toDouble()
                : null;
            final lat = coords != null && coords.length > 1
                ? (coords[1] as num?)?.toDouble()
                : null;

            final name = props['name']?.toString().trim() ?? '';
            final house = props['housenumber']?.toString().trim() ?? '';
            final street = props['street']?.toString().trim() ?? '';
            final district = props['district']?.toString().trim() ??
                props['locality']?.toString().trim() ??
                '';
            final city = props['city']?.toString().trim() ?? '';
            final state = props['state']?.toString().trim() ?? '';
            final country = props['country']?.toString().trim() ?? '';
            final rawPost = props['postcode']?.toString().trim() ?? '';
            final pincode = extractPinCode(rawPost).isNotEmpty
                ? extractPinCode(rawPost)
                : rawPost;

            final streetLine = [house, street].where((s) => s.isNotEmpty).join(' ');
            final mainText = name.isNotEmpty
                ? name
                : (streetLine.isNotEmpty ? streetLine : district);
            final parts = <String>[
              if (name.isNotEmpty) name,
              if (streetLine.isNotEmpty && streetLine != name) streetLine,
              if (district.isNotEmpty && district != name) district,
              if (city.isNotEmpty && city != district) city,
              if (state.isNotEmpty) state,
            ];
            final full = parts.join(', ');
            final secondary = [district, city, state, pincode]
                .where((s) => s.isNotEmpty && s != mainText)
                .join(', ');

            return LocationAddressResult(
              fullAddress: full.isNotEmpty ? full : cleanQuery,
              mainText: mainText.isNotEmpty ? mainText : cleanQuery,
              secondaryText: secondary.isNotEmpty ? secondary : full,
              houseNo: streetLine.isNotEmpty ? streetLine : name,
              landmark: district.isNotEmpty ? 'Near $district' : '',
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
    } catch (_) {}
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

    final response = await http.get(url).timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
        final result = Map<String, dynamic>.from(data['results'][0] as Map);
        return _parseGooglePlaceResult(result, fallbackLat: lat, fallbackLng: lng);
      }
    }
    return null;
  }

  static LocationAddressResult? _parseGooglePlaceResult(
    Map<String, dynamic> result, {
    double? fallbackLat,
    double? fallbackLng,
  }) {
    final formattedAddress = result['formatted_address']?.toString() ?? '';
    final components = result['address_components'] as List? ?? [];
    final geom = result['geometry'] is Map
        ? Map<String, dynamic>.from(result['geometry'] as Map)
        : null;
    final loc = geom?['location'] is Map
        ? Map<String, dynamic>.from(geom!['location'] as Map)
        : null;
    final lat = (loc?['lat'] as num?)?.toDouble() ?? fallbackLat;
    final lng = (loc?['lng'] as num?)?.toDouble() ?? fallbackLng;

    String houseNo = '';
    String route = '';
    String sublocality = '';
    String city = '';
    String state = '';
    String pincode = '';
    String country = '';

    for (var comp in components) {
      final types = comp['types'] as List? ?? [];
      final longName = comp['long_name']?.toString() ?? '';
      if (types.contains('street_number')) houseNo = longName;
      if (types.contains('route')) route = longName;
      if (types.contains('sublocality') || types.contains('sublocality_level_1')) {
        sublocality = longName;
      }
      if (types.contains('locality')) city = longName;
      if (types.contains('administrative_area_level_1')) state = longName;
      if (types.contains('postal_code')) pincode = longName;
      if (types.contains('country')) country = longName;
    }

    final streetCombined = [houseNo, route].where((s) => s.isNotEmpty).join(' ');
    final resolvedPin = pincode.isNotEmpty ? pincode : extractPinCode(formattedAddress);

    return LocationAddressResult(
      fullAddress: formattedAddress,
      mainText: sublocality.isNotEmpty
          ? sublocality
          : (streetCombined.isNotEmpty ? streetCombined : city),
      secondaryText: [city, state, resolvedPin].where((s) => s.isNotEmpty).join(', '),
      houseNo: streetCombined,
      landmark: sublocality.isNotEmpty ? 'Near $sublocality' : '',
      pincode: resolvedPin,
      city: city,
      state: state,
      country: country,
      latitude: lat,
      longitude: lng,
    );
  }
}
