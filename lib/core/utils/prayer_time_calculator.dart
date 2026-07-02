import 'dart:math' as math;

/// Computes Fajr (dawn) and Maghrib (sunset) for a given date/location —
/// used to suggest Suhoor/Iftar times for a Ramadan fast. Pure
/// astronomical calculation (solar position + equation of time), no
/// network call — keeps the app fully offline. Accuracy is roughly
/// within a minute or two of official published times, which is fine
/// for a suggested starting point; the sheet always lets the user adjust
/// the picked time afterward.
///
/// Uses the Muslim World League convention (Fajr at 18° below horizon)
/// and standard sunset (sun's center 0.833° below horizon, accounting
/// for atmospheric refraction and the sun's apparent radius).
class PrayerTimeCalculator {
  PrayerTimeCalculator._();

  static const double _fajrAngle = 18.0;
  static const double _sunsetAngle = 0.833;

  /// Returns (fajr, maghrib) as local [DateTime]s on [date], for the
  /// given [latitude]/[longitude] and [utcOffsetHours] (the location's
  /// timezone offset from UTC, e.g. 5.0 for UTC+5).
  static ({DateTime fajr, DateTime maghrib}) calculate({
    required DateTime date,
    required double latitude,
    required double longitude,
    required double utcOffsetHours,
  }) {
    final jd = _julianDate(date.year, date.month, date.day);

    final fajrHour = _sunAngleTime(
      angle: _fajrAngle,
      jd: jd,
      latitude: latitude,
      longitude: longitude,
      utcOffsetHours: utcOffsetHours,
      beforeNoon: true,
    );
    final maghribHour = _sunAngleTime(
      angle: _sunsetAngle,
      jd: jd,
      latitude: latitude,
      longitude: longitude,
      utcOffsetHours: utcOffsetHours,
      beforeNoon: false,
    );

    return (
      fajr: _hourToDateTime(date, fajrHour),
      maghrib: _hourToDateTime(date, maghribHour),
    );
  }

  static DateTime _hourToDateTime(DateTime date, double hour) {
    final h = hour.floor();
    final minutes = ((hour - h) * 60).round();
    return DateTime(date.year, date.month, date.day, h, minutes);
  }

  static double _sunAngleTime({
    required double angle,
    required double jd,
    required double latitude,
    required double longitude,
    required double utcOffsetHours,
    required bool beforeNoon,
  }) {
    final sun = _sunPosition(jd);
    final decl = sun.declination;
    final eqt = sun.equation;

    final noon = _fixHour(12 - eqt);

    final numerator = -_sinDeg(angle) - _sinDeg(decl) * _sinDeg(latitude);
    final denominator = _cosDeg(decl) * _cosDeg(latitude);
    final cosArg = (numerator / denominator).clamp(-1.0, 1.0);
    final t = _rtd(math.acos(cosArg)) / 15.0;

    final greenwichHour = beforeNoon ? noon - t : noon + t;
    // Converts the Greenwich-referenced solar hour to the location's
    // clock time: shift by the timezone offset and by longitude (each
    // 15° of longitude is 1 hour of solar time).
    return greenwichHour + utcOffsetHours - longitude / 15.0;
  }

  static ({double declination, double equation}) _sunPosition(double jd) {
    final d = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _fixAngle(q + 1.915 * _sinDeg(g) + 0.020 * _sinDeg(2 * g));

    final e = 23.439 - 0.00000036 * d;

    final declination = _rtd(math.asin(_sinDeg(e) * _sinDeg(l)));
    var rightAscension = _rtd(math.atan2(_cosDeg(e) * _sinDeg(l), _cosDeg(l))) / 15.0;
    rightAscension = _fixHour(rightAscension);

    final equation = q / 15.0 - rightAscension;
    return (declination: declination, equation: equation);
  }

  static double _julianDate(int year, int month, int day) {
    var y = year;
    var m = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floorToDouble() +
        (30.6001 * (m + 1)).floorToDouble() +
        day +
        b -
        1524.5;
  }

  static double _dtr(double d) => d * math.pi / 180.0;
  static double _rtd(double r) => r * 180.0 / math.pi;
  static double _sinDeg(double d) => math.sin(_dtr(d));
  static double _cosDeg(double d) => math.cos(_dtr(d));

  static double _fixHour(double hour) {
    var h = hour % 24.0;
    if (h < 0) h += 24.0;
    return h;
  }

  static double _fixAngle(double angle) {
    var a = angle % 360.0;
    if (a < 0) a += 360.0;
    return a;
  }
}
