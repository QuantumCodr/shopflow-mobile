/// ShopFlow business time utilities.
///
/// ShopFlow currently uses Sierra Leone business time (UTC+00:00).
/// Store timestamps as UTC instants, calculate business-day boundaries
/// in UTC, and display timestamps in UTC as Sierra Leone time.
abstract final class ShopFlowTime {
  /// Returns the current instant in UTC.
  static DateTime nowUtc() {
    return DateTime.now().toUtc();
  }

  /// Returns midnight at the start of today in Sierra Leone.
  static DateTime startOfTodayUtc() {
    final now = nowUtc();

    return DateTime.utc(
      now.year,
      now.month,
      now.day,
    );
  }

  /// Returns midnight at the start of tomorrow in Sierra Leone.
  ///
  /// This is an exclusive boundary for database queries.
  static DateTime startOfTomorrowUtc() {
    final today = startOfTodayUtc();

    return DateTime.utc(
      today.year,
      today.month,
      today.day + 1,
    );
  }

  /// Converts a timestamp to UTC for Sierra Leone display.
  static DateTime toBusinessTime(DateTime timestamp) {
    return timestamp.toUtc();
  }
}