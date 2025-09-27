// lib/utils/unit_recognition.dart
import 'dart:math' as math;

/// What we recognized from a raw unit string.
class UnitRecognition {
  final bool recognized;

  /// Canonical unit id (e.g., mm, cm, m, in, ft, g, kg, lb, oz).
  final String normalized;

  /// Family groups which conversions make sense for (length, mass).
  final String family;

  /// Human-facing abbreviation to display next to numbers.
  final String displayUnit;

  const UnitRecognition({
    required this.recognized,
    required this.normalized,
    required this.family,
    required this.displayUnit,
  });

  bool get isLength => family == 'length';
  bool get isMass => family == 'mass';

  /// Return a list of conversion suggestions for a numeric value in this unit.
  List<ConvResult> conversions(double value) {
    if (!recognized) return const [];
    if (isLength) {
      // normalize to millimeters
      final mm = _toMm(value, normalized);
      return <ConvResult>[
        ConvResult(label: 'millimeters', unit: 'mm', value: mm),
        ConvResult(label: 'centimeters', unit: 'cm', value: mm / 10.0),
        ConvResult(label: 'meters', unit: 'm', value: mm / 1000.0),
        ConvResult(label: 'inches', unit: 'in', value: mm / 25.4),
        ConvResult(label: 'feet', unit: 'ft', value: (mm / 25.4) / 12.0),
      ];
    }
    if (isMass) {
      // normalize to grams
      final g = _toG(value, normalized);
      return <ConvResult>[
        ConvResult(label: 'grams', unit: 'g', value: g),
        ConvResult(label: 'kilograms', unit: 'kg', value: g / 1000.0),
        ConvResult(label: 'ounces', unit: 'oz', value: g / 28.349523125),
        ConvResult(label: 'pounds', unit: 'lb', value: g / 453.59237),
      ];
    }
    return const [];
  }
}

class ConvResult {
  final String label;
  final String unit;
  final double value;
  const ConvResult({
    required this.label,
    required this.unit,
    required this.value,
  });
}

/// Main entry point: parse a raw unit string into a UnitRecognition.
UnitRecognition recognizeUnit(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) {
    return const UnitRecognition(
      recognized: false,
      normalized: '',
      family: '',
      displayUnit: '',
    );
  }

  // normalize punctuation and case
  var t = s.toLowerCase();
  t = t.replaceAll(RegExp(r'[\.\s]+'), ''); // remove dots/spaces
  // common quote characters for ft (') and in (")
  t = t.replaceAll('″', '"').replaceAll('”', '"').replaceAll('“', '"');
  t = t.replaceAll('′', "'").replaceAll('’', "'").replaceAll('‘', "'");

  // ----- length -----
  if (_match(t, ['mm', 'millimeter', 'millimeters'])) {
    return const UnitRecognition(
      recognized: true,
      normalized: 'mm',
      family: 'length',
      displayUnit: 'mm',
    );
  }
  if (_match(t, ['cm', 'centimeter', 'centimeters'])) {
    return const UnitRecognition(
      recognized: true,
      normalized: 'cm',
      family: 'length',
      displayUnit: 'cm',
    );
  }
  if (_match(t, ['m', 'meter', 'meters'])) {
    return const UnitRecognition(
      recognized: true,
      normalized: 'm',
      family: 'length',
      displayUnit: 'm',
    );
  }
  if (_match(t, ['in', 'inch', 'inches', '"'])) {
    return const UnitRecognition(
      recognized: true,
      normalized: 'in',
      family: 'length',
      displayUnit: 'in',
    );
  }
  if (_match(t, ['ft', 'foot', 'feet', "'"])) {
    return const UnitRecognition(
      recognized: true,
      normalized: 'ft',
      family: 'length',
      displayUnit: 'ft',
    );
  }

  // ----- mass -----
  if (_match(t, ['g', 'gram', 'grams'])) {
    return const UnitRecognition(
      recognized: true,
      normalized: 'g',
      family: 'mass',
      displayUnit: 'g',
    );
  }
  if (_match(t, ['kg', 'kilogram', 'kilograms'])) {
    return const UnitRecognition(
      recognized: true,
      normalized: 'kg',
      family: 'mass',
      displayUnit: 'kg',
    );
  }
  if (_match(t, ['lb', 'lbs', 'pound', 'pounds'])) {
    return const UnitRecognition(
      recognized: true,
      normalized: 'lb',
      family: 'mass',
      displayUnit: 'lb',
    );
  }
  if (_match(t, ['oz', 'ounce', 'ounces'])) {
    return const UnitRecognition(
      recognized: true,
      normalized: 'oz',
      family: 'mass',
      displayUnit: 'oz',
    );
  }

  // Unknown
  return UnitRecognition(
    recognized: false,
    normalized: s,
    family: '',
    displayUnit: s,
  );
}

bool _match(String t, List<String> opts) => opts.any((o) => t == o);

double _toMm(double value, String unit) {
  switch (unit) {
    case 'mm':
      return value;
    case 'cm':
      return value * 10.0;
    case 'm':
      return value * 1000.0;
    case 'in':
      return value * 25.4;
    case 'ft':
      return value * 12.0 * 25.4;
    default:
      return value;
  }
}

double _toG(double value, String unit) {
  switch (unit) {
    case 'g':
      return value;
    case 'kg':
      return value * 1000.0;
    case 'oz':
      return value * 28.349523125;
    case 'lb':
      return value * 453.59237;
    default:
      return value;
  }
}

/// Nicely format a number for UI display.
String fmtNumber(num v) {
  final n = v.toDouble();
  if (n == 0) return '0';
  // 3 decimals max, trim trailing zeros
  final s = n.toStringAsFixed(3);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}
