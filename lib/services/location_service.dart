import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Detects the user's country via GPS (primary) or IP geolocation (fallback).
class LocationService {
  static const _countryKey = 'cached_country';
  static const _countryCodeKey = 'cached_country_code';

  /// Get the user's country. Returns a map with 'country' and 'countryCode'.
  Future<Map<String, String>> getCountry() async {
    // Try cached first
    final cached = await _getCached();
    if (cached != null) return cached;

    // Try GPS
    try {
      final gps = await _getFromGPS();
      if (gps != null) {
        await _cache(gps);
        return gps;
      }
    } catch (e) {
      logger.w('GPS country detection failed', error: e);
    }

    // Fallback: IP-based
    try {
      final ip = await _getFromIP();
      if (ip != null) {
        await _cache(ip);
        return ip;
      }
    } catch (e) {
      logger.w('IP country detection failed', error: e);
    }

    return {'country': 'Unknown', 'countryCode': ''};
  }

  Future<Map<String, String>?> _getFromGPS() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      return {
        'country': placemarks.first.country ?? 'Unknown',
        'countryCode': placemarks.first.isoCountryCode ?? '',
      };
    }
    return null;
  }

  Future<Map<String, String>?> _getFromIP() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'country': data['country_name'] as String? ?? 'Unknown',
          'countryCode': data['country_code'] as String? ?? '',
        };
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, String>?> _getCached() async {
    final prefs = await SharedPreferences.getInstance();
    final country = prefs.getString(_countryKey);
    final code = prefs.getString(_countryCodeKey);
    if (country != null && code != null) {
      return {'country': country, 'countryCode': code};
    }
    return null;
  }

  Future<void> _cache(Map<String, String> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countryKey, data['country']!);
    await prefs.setString(_countryCodeKey, data['countryCode']!);
  }
}
