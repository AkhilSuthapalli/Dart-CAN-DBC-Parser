import 'dart:convert';
import 'dart:typed_data';

import 'bitfield/bit_field.dart';
import 'signal/dbc_signal.dart';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';


const int canIdLength = 2; // in bytes
const int byteLen = 8; // in bits
const int maxPayload = 8; // in bytes

/// An object that stores multiple [DBCSignal]-s along with information needed to decode them
class DBCDatabase {
  /// Map of [DBCSignal]-s used for decoding. Signals are grouped by their dedcimal CAN id's.
  final Map<int, Map<String, DBCSignal>> database;

  /// Length of each CAN message, the key is the decimal CAN id
  final Map<int, int> messageLengths;

  /// Defines whether a message designated by its CAN id has multiplex groups
  final Map<int, bool> isMultiplex;

  /// Shortcut for finding the [DBCSignalMode.MULTIPLEXOR] of a message
  final Map<int, String> multiplexors;

  DBCDatabase(
      {required this.database,
        required this.messageLengths,
        required this.isMultiplex,
        required this.multiplexors});

  static void registerWith(Registrar registrar) {
    // Perform any web-specific plugin registration here.
    // print('DBCDatabase registered for web');
  }

  /// The initial loading function.
  ///
  /// This function may throw, when any of the given files dont exist.
  /// If the given file is not in line with DBC format then it will return a [DBCDatabase] with empty [DBCDatabase.database] field, an will therefore not decode anything
  static Future<DBCDatabase> loadFromBytes(Uint8List bytes) async {
    Map<int, Map<String, DBCSignal>> database = {};
    Map<int, int> messageLengths = {};
    Map<int, bool> isMultiplex = {};
    Map<int, String> multiplexors = {};

    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] > 127) {
        bytes[i] = 33; // !
      }
    }

    List<String> lines = AsciiDecoder().convert(bytes).split('\n');

    RegExp messageRegex = RegExp(
      r"BO_\s[0-9]{1,4}\s[a-zA-z0-9]+:\s\d\s[a-zA-z]+",
    );
    RegExp signalRegex = RegExp(
        r"\sSG_\s[a-zA-Z0-9_ ]+\s:\s[0-9\S]+\s[\S0-9]+\s[\S0-9]+\s[a-zA-Z\S]+\s{1,2}[a-zA-z]+");

    RegExp messageIdRegex = RegExp(r"BO_\s[0-9]{1,4}");
    RegExp messageLengthRegex = RegExp(r":\s\d\s");

    RegExp signalNameRegex = RegExp(r"SG_\s[a-zA-Z0-9_ ]+");

    bool messageContinuation = false;
    int canId = 0;

    for (String line in lines) {
      if (!messageContinuation && messageRegex.hasMatch(line)) {
        messageContinuation = true;

        RegExpMatch canIdMatch = messageIdRegex.firstMatch(line)!;
        RegExpMatch canLenghtMatch = messageLengthRegex.firstMatch(line)!;

        canId = int.parse(canIdMatch[0]!.substring(4));
        int length = int.parse(canLenghtMatch[0]!.substring(2, 3));

        messageLengths[canId] = length;
        database[canId] = {};
      } else if (messageContinuation && signalRegex.hasMatch(line)) {
        String signalName =
        signalNameRegex.firstMatch(line)![0]!.substring(4);
        if (signalName.endsWith(' ')) {
          signalName = signalName.substring(0, signalName.length - 1);
        }
        database[canId]![signalName] =
            DBCSignal.fromString(line, messageLengths[canId]! * 8);
      } else if (messageContinuation && !signalRegex.hasMatch(line)) {
        messageContinuation = false;
        canId = 0;
      }
    }

    // Post process
    for (int canId in database.keys) {
      if (database[canId]!.values.any(
              (element) => element.signalMode == DBCSignalMode.MULTIPLEX_GROUP)) {
        isMultiplex[canId] = true;
        multiplexors[canId] = database[canId]!.keys.firstWhere((element) =>
        database[canId]![element]!.signalMode == DBCSignalMode.MULTIPLEXOR);
      } else {
        isMultiplex[canId] = false;
      }
    }

    return DBCDatabase(
        database: database,
        messageLengths: messageLengths,
        isMultiplex: isMultiplex,
        multiplexors: multiplexors);
  }

  /// A decode function that runs on a [Uint8List], eg. from a socket
  ///
  /// Returns a map of successfully decoded signals, if a [DBCSignal] was determined to be out of range specified by [DBCSignal.min] and [DBCSignal.max], that value is omitted from the returned map
  Map<String, num> decode(Uint8List bytes) {
    int mainOffset = 0;
    Map<String, num> decoded = {};

    while (mainOffset < bytes.length - canIdLength) {
      while (!database.containsKey(bytes
          .sublist(mainOffset, mainOffset + canIdLength)
          .buffer
          .asByteData()
          .getUint16(0))) {
        mainOffset++;
        if (mainOffset >= bytes.length - canIdLength) {
          return decoded;
        }
      }
      int canId = bytes
          .sublist(mainOffset, mainOffset + canIdLength)
          .buffer
          .asByteData()
          .getUint16(0);
      mainOffset += canIdLength;

      Map<String, DBCSignal> messageData = database[canId]!;
      int messageLength = messageLengths[canId]!;
      if (bytes.length - mainOffset < messageLength) {
        return decoded;
      }

      List<int> payloadBitField =
      BitField.from(bytes.sublist(mainOffset, mainOffset + messageLength));

      mainOffset += messageLength;
      if (isMultiplex[canId]!) {
        int? activeMultiplexGroup =
        messageData[multiplexors[canId]]!.decode(payloadBitField)?.toInt();
        if (activeMultiplexGroup == null) {
          continue;
        }
        messageData.forEach((signalName, signalData) {
          if (signalData.signalMode == DBCSignalMode.SIGNAL ||
              signalData.signalMode == DBCSignalMode.MULTIPLEX_GROUP &&
                  signalData.multiplexGroup == activeMultiplexGroup) {
            final num? signalValue = signalData.decode(payloadBitField);
            if (signalValue != null) {
              decoded[signalName] = signalValue;
            }
          }
        });
      } else {
        for (String signalName in messageData.keys) {
          final num? signalValue =
          messageData[signalName]!.decode(payloadBitField);
          if (signalValue != null) {
            decoded[signalName] = signalValue;
          }
        }
      }
    }
    return decoded;
  }

  Uint8List encodeMessage(int canId) {
    // Ensure the CAN ID exists in the database
    if (!database.containsKey(canId)) {
      throw ArgumentError("CAN ID $canId not found in database.");
    }

    // Retrieve the signals for the given CAN ID
    Map<String, DBCSignal> signals = database[canId]!;

    // Create an 8-byte CAN frame (standard size)
    List<int> message = List.filled(10, 0);

    // Encode CAN ID (2 bytes for 11-bit CAN IDs)
    message[0] = (canId >> 8) & 0xFF; // High byte of CAN ID
    message[1] = canId & 0xFF;        // Low byte of CAN ID

    // For each signal, encode its value into the message's payload
    List<int> payloadBitField = BitField.from(Uint8List(messageLengths[canId]!));

    for (var signalEntry in signals.entries) {
      DBCSignal signal = signalEntry.value;
      payloadBitField = signal.encode(payloadBitField);
    }
    List<int> byteValue = BitField.convert64BitListTo8Bit(payloadBitField);

    for (int i = 0; i<8; i++){
      message[2+i]=byteValue[i];
    }
    return Uint8List.fromList(message);
  }
  

}
