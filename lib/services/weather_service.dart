import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Current weather from OpenWeatherMap.
///
/// TO ENABLE: get a free key at https://openweathermap.org/api and paste it
/// into [apiKey] below. Until then every weather UI hides itself rather than
/// showing an error — the app works perfectly well without it.
///
/// An embedded weather key is low-risk (worst case someone burns your free
/// quota), unlike an AI or payment key, which is why this one is allowed to
/// live in the client at all.
class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  static const String apiKey = '';

  /// Default location used when no coordinates are supplied. There's no
  /// location plugin in the build, so this is a fixed city rather than GPS.
  static const String defaultCity = 'Mumbai';

  static bool get enabled => apiKey.isNotEmpty;

  Future<WeatherInfo?> current({String? city}) async {
    if (!enabled) return null;
    try {
      final uri = Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather'
          '?q=${city ?? defaultCity}&units=metric&appid=$apiKey');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final main = json['main'] as Map<String, dynamic>?;
      final weatherList = json['weather'] as List?;
      final weather = (weatherList != null && weatherList.isNotEmpty)
          ? weatherList.first as Map<String, dynamic>
          : null;

      return WeatherInfo(
        city: (json['name'] ?? city ?? defaultCity).toString(),
        temp: ((main?['temp'] ?? 0) as num).toDouble(),
        feelsLike: ((main?['feels_like'] ?? 0) as num).toDouble(),
        description: (weather?['description'] ?? '').toString(),
        icon: (weather?['main'] ?? '').toString(),
      );
    } catch (e) {
      debugPrint('Weather fetch failed: $e');
      return null;
    }
  }
}

class WeatherInfo {
  final String city;
  final double temp;
  final double feelsLike;
  final String description;
  final String icon;

  WeatherInfo({
    required this.city,
    required this.temp,
    required this.feelsLike,
    required this.description,
    required this.icon,
  });

  /// Maps OpenWeatherMap's condition names to a matching emoji.
  String get emoji => switch (icon.toLowerCase()) {
        'clear' => '☀️',
        'clouds' => '☁️',
        'rain' || 'drizzle' => '🌧️',
        'thunderstorm' => '⛈️',
        'snow' => '❄️',
        'mist' || 'haze' || 'fog' || 'smoke' => '🌫️',
        _ => '🌤️',
      };
}
