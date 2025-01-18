import '../bitfield/bit_field.dart';

/// An enum to signal signedness
enum DBCSignalSignedness {
  // ignore: constant_identifier_names
  SIGNED,
  // ignore: constant_identifier_names
  UNSIGNED
}

/// An enum to signal type, eq INTEL and MOTOROLA
enum DBCSignalType {
  // ignore: constant_identifier_names
  INTEL,
  // ignore: constant_identifier_names
  MOTOROLA
}

/// An enum to signal mode, such as standalone SIGNAL or MULTIPLEX GROUP and MULTIPLEXOR
enum DBCSignalMode {
  // ignore: constant_identifier_names
  SIGNAL,
  // ignore: constant_identifier_names
  MULTIPLEXOR,
  // ignore: constant_identifier_names
  MULTIPLEX_GROUP,
}

/// An object that stores necessary data to decode a CAN signal
class DBCSignal {
  DBCSignal({
    required this.signalSignedness,
    required this.signalType,
    required this.signalMode,
    required this.multiplexGroup,
    required this.start,
    required this.length,
    required this.mapping,
    required this.mappingIndexes,
    required this.factor,
    required this.offset,
    required this.min,
    required this.max,
    required this.unit,
    required this.value
  });

  final DBCSignalSignedness signalSignedness;
  final DBCSignalType signalType;
  final DBCSignalMode signalMode;
  final int multiplexGroup;
  final int start;
  final int length;

  /// Specifies how the payload bits count towards a decoded value
  final List<int> mapping;

  /// Specifies the used bits in the payload
  final List<int> mappingIndexes;
  final double factor;
  final double offset;
  final double min;
  final double max;
  final String unit;
  double value;

  static RegExp signednessRegex = RegExp(r"@\d[+-]{1}");
  static RegExp multiplexorRegex = RegExp(r" M ");
  static RegExp multiplexGroupRegex = RegExp(r" m\d ");
  static RegExp startbitRegex = RegExp(r": [0-9]+\|");
  static RegExp lenghtRegex = RegExp(r"\|[0-9]+@");
  static RegExp factorRegex = RegExp(r"\([0-9.Ee-]+,");
  static RegExp offsetRegex = RegExp(r",[0-9.-]+\)");
  static RegExp minRegex = RegExp(r"\[[0-9.-]+\|");
  static RegExp maxRegex = RegExp(r"\|[0-9.-]+\]");
  static RegExp unitRegex = RegExp(r'\] "[a-zA-Z\/0-9%!^°\s]*" ');

  /// When a DBC file is initially parsed each signals are constructed on a line-by-line basis
  static DBCSignal fromString(String data, int lenghtOfMessage) {
    DBCSignalSignedness signalSignedness;
    DBCSignalType signalType;
    DBCSignalMode signalMode;
    int multiplexGroup;
    int length;
    int start;
    List<int> mapping;
    List<int> mappingIndexes;
    double factor;
    double offset;
    double min;
    double max;
    String unit;
    double value;

    signalSignedness = signednessRegex.firstMatch(data)![0]!.contains('-')
        ? DBCSignalSignedness.SIGNED
        : DBCSignalSignedness.UNSIGNED;
    signalType = signednessRegex.firstMatch(data)![0]!.contains('0')
        ? DBCSignalType.MOTOROLA
        : DBCSignalType.INTEL;

    if (multiplexGroupRegex.hasMatch(data)) {
      signalMode = DBCSignalMode.MULTIPLEX_GROUP;
      multiplexGroup =
          int.parse(multiplexGroupRegex.firstMatch(data)![0]!.substring(2, 3));
    } else {
      multiplexGroup = -1;
      signalMode = multiplexorRegex.hasMatch(data)
          ? DBCSignalMode.MULTIPLEXOR
          : DBCSignalMode.SIGNAL;
    }

    String startMatch = startbitRegex.firstMatch(data)![0]!.substring(2);
    start = int.parse(startMatch.substring(0, startMatch.length - 1));
    String lenghtMatch = lenghtRegex.firstMatch(data)![0]!.substring(1);
    length = int.parse(lenghtMatch.substring(0, lenghtMatch.length - 1));

    mapping = BitField.getMapping(length, start, signalType);
    mappingIndexes = mapping
        .asMap()
        .keys
        .toList()
        .where((element) => mapping[element] != 0)
        .toList();

    String factorMatch = factorRegex.firstMatch(data)![0]!.substring(1);
    factor = double.parse(factorMatch.substring(0, factorMatch.length - 1));
    String offsetMatch = offsetRegex.firstMatch(data)![0]!.substring(1);
    offset = double.parse(offsetMatch.substring(0, offsetMatch.length - 1));

    String minMatch = minRegex.firstMatch(data)![0]!.substring(1);
    min = double.parse(minMatch.substring(0, minMatch.length - 1));
    String maxMatch = maxRegex.firstMatch(data)![0]!.substring(1);
    max = double.parse(maxMatch.substring(0, maxMatch.length - 1));
    String unitMatch = unitRegex.firstMatch(data)![0]!.substring(3);
    unit = unitMatch.substring(0, unitMatch.length - 2);

    value = min;

    return DBCSignal(
        signalSignedness: signalSignedness,
        signalType: signalType,
        signalMode: signalMode,
        multiplexGroup: multiplexGroup,
        start: start,
        length: length,
        mapping: mapping,
        mappingIndexes: mappingIndexes,
        factor: factor,
        offset: offset,
        min: min,
        max: max,
        value: value,
        unit: unit);
  }

  /// The bit level representation of the payload is multiplied with the signals mapping to form a decoded value
  /// This value changes sign dependent on [DBCSignalSignedness], and then is multiplied by the factor, and offseted my the offset
  /// If a value turns out to be out of range specified by [min] and [max] null is returned
  num? decode(List<int> payload) {
    int val = 0;
    for (int i in mappingIndexes) {
      val += payload[i] * mapping[i];
    }
    if (signalSignedness == DBCSignalSignedness.SIGNED) {
      val = val.toSigned(length);
    }
    final double scaled = val * factor + offset;
    if (min <= scaled && scaled <= max) {
      return scaled;
    }
    return null;
  }

  List<int> encode(List<int> payload) {
    // Apply the scaling and offset
    int rawValue = ((value - offset) / factor).round();
    // Handle signedness if the signal is signed
    if (signalSignedness == DBCSignalSignedness.SIGNED) {
      // Convert to signed value (two's complement)
      rawValue = rawValue & ((1 << length) - 1);  // Mask to fit within the signal's length
    }

    for (int i = 0; i < mappingIndexes.length; i++) {
      int bitPos = mappingIndexes[i];  // Get the bit position
      int bitValue = (rawValue & mapping[bitPos]) != 0 ? 1 : 0; // Extract the bit based on the mask
      payload[bitPos] = bitValue;
    }

    return payload;
  }


}
