/// Formats integer minor currency units as an SLE amount.
///
/// Example: 1250 becomes "12.50".
String formatSleMinor(int minorUnits) {
  final wholeUnits = minorUnits ~/ 100;
  final fractionalUnits =
      (minorUnits % 100).abs().toString().padLeft(2, '0');

  return '$wholeUnits.$fractionalUnits';
}

/// Converts an SLE amount entered by the user into minor units.
///
/// Accepts whole amounts or up to two decimal places.
/// Examples: "25" -> 2500; "25.50" -> 2550.
int? parseSleToMinor(String input) {
  final value = input.trim();

  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value)) {
    return null;
  }

  final parts = value.split('.');
  final wholeUnits = int.tryParse(parts[0]);

  if (wholeUnits == null) return null;

  final fractionalText =
      parts.length == 2 ? parts[1].padRight(2, '0') : '00';

  final fractionalUnits = int.tryParse(fractionalText);

  if (fractionalUnits == null) return null;

  return wholeUnits * 100 + fractionalUnits;
}