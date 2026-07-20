import 'package:freezed_annotation/freezed_annotation.dart';

/// Serialises [Duration] as whole microseconds.
///
/// json_serializable has no built-in Duration support. Microseconds are used
/// rather than milliseconds because run timings are compared against par times
/// for star ratings, and rounding a stored duration is a way to lose a star.
class DurationConverter implements JsonConverter<Duration, int> {
  const DurationConverter();

  @override
  Duration fromJson(int json) => Duration(microseconds: json);

  @override
  int toJson(Duration object) => object.inMicroseconds;
}

/// Serialises [DateTime] as an ISO-8601 UTC string.
///
/// Always normalised to UTC on write. Storing local times in a save that syncs
/// across devices and timezones produces bugs that only appear when a player
/// travels, which is the worst possible time to discover them.
class UtcDateTimeConverter implements JsonConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json).toUtc();

  @override
  String toJson(DateTime object) => object.toUtc().toIso8601String();
}

/// Nullable variant of [UtcDateTimeConverter].
class NullableUtcDateTimeConverter
    implements JsonConverter<DateTime?, String?> {
  const NullableUtcDateTimeConverter();

  @override
  DateTime? fromJson(String? json) =>
      json == null ? null : DateTime.parse(json).toUtc();

  @override
  String? toJson(DateTime? object) => object?.toUtc().toIso8601String();
}
