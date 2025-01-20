import 'dart:math';
import 'dart:typed_data';

import '../can_dbc_parser.dart';
import '../signal/dbc_signal.dart';

/// An interface to prepare payload for decoding
abstract class BitField {
  /// Returns a List as the bit level representation of the payload
  ///
  /// CAN decoding requires this bit level representation to be mirrored byte by byte
  static List<int> from(Uint8List bytes) {
    List<int> data = List.filled(64, 0);
    int byteCnt = 0;
    for (int byte in bytes) {
      int mask = 1 << (byteLen - 1);
      for (int bit = 0; bit < byteLen; bit++, mask >>= 1) {
        data[byteCnt * byteLen + byteLen - bit - 1] =
            (byte & mask != 0 ? 1 : 0);
      }
      byteCnt++;
    }
    return data;
  }

  /// Returns a list as byte level from bits
  ///
  /// CAN encoding requires this as to form the 8 byte message.
  static List<int> convert64BitListTo8Bit(List<int> bitList) {
    // List to store the 8-bit integers
    List<int> byteList = [];

    // Loop through the bitList in chunks of 8 bits
    for (int i = 0; i < bitList.length; i += 8) {
      int byteValue = 0;

      // Convert the 8-bit slice to a single byte
      var byteValue2 = List.from(bitList.sublist(i, i + 8).reversed);
      for (int j = 0; j < 8; j++) {
        byteValue |= (byteValue2[j] << (7 - j)); // Shift to position (7-j)
      }

      byteList.add(byteValue);
    }

    return byteList;
  }

  /// Returns a mapping to be used when decoding
  ///
  /// This mapping contains the weight each bit will have towards a decoded value
  static List<int> getMapping(int length, int start, DBCSignalType signalType) {
    if (signalType == DBCSignalType.INTEL) {
      List<int> data = List.filled(64, 0);
      int exp = 0;
      List<int> indexes = List.filled(length, 0);
      int idxIdx = 0;
      while (idxIdx < indexes.length) {
        indexes[idxIdx++] = start++;
      }

      for (int byte = 0; byte < maxPayload; byte++) {
        int offset = byte * byteLen;
        for (int bit = offset; bit < offset + byteLen; bit++) {
          if (indexes.contains(bit)) {
            data[bit] = pow(2, exp++).toInt();
          }
        }
      }
      return data;
    } else {
      List<int> data = List.filled(64, 0);
      int exp = length - 1;

      int trueStart = start;
      if (start.remainder(byteLen) < length) {
        trueStart = start - start.remainder(byteLen);
      } else {
        trueStart = start - length + 1;
      }
      List<int> indexes = List.filled(length, 0);
      int idxIdx = 0;
      int rem = 0;
      rem = start.remainder(byteLen) == 0 ? 8 : start.remainder(byteLen) + 1;
      rem = min(rem, length);
      while (idxIdx < indexes.length) {
        indexes[idxIdx] = trueStart + rem - 1;
        idxIdx++;
        trueStart--;
        if ((trueStart + rem) % byteLen == 0) {
          trueStart += (byteLen + rem + (length - idxIdx).remainder(byteLen));
          rem = (length - idxIdx).remainder(byteLen) == 0
              ? 8
              : (length - idxIdx).remainder(byteLen);
        }
      }

      for (int byte = 0; byte < maxPayload; byte++) {
        int offset = byte * byteLen;
        for (int bit = byteLen - 1 + offset; bit >= offset; bit--) {
          if (indexes.contains(bit)) {
            data[bit] = pow(2, exp--).toInt();
          }
        }
      }
      return data;
    }
  }
}
