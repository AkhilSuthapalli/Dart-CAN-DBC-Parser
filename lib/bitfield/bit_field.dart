import 'dart:math';
import 'dart:typed_data';

import '../dart_dbc_parser_web.dart';
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

  /// Returns a mapping to be used when decoding
  ///
  /// This mapping contains the weigth each bit will have towards a decoded value
  static List<int> getMapping(int lenght, int start, DBCSignalType signalType) {
    if (signalType == DBCSignalType.INTEL) {
      List<int> data = List.filled(64, 0);
      int exp = 0;
      List<int> indexes = List.filled(lenght, 0);
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
      int exp = lenght - 1;

      int trueStart = start;
      if (start.remainder(byteLen) < lenght) {
        trueStart = start - start.remainder(byteLen);
      } else {
        trueStart = start - lenght + 1;
      }
      List<int> indexes = List.filled(lenght, 0);
      int idxIdx = 0;
      int rem = 0;
      rem = start.remainder(byteLen) == 0 ? 8 : start.remainder(byteLen) + 1;
      rem = min(rem, lenght);
      while (idxIdx < indexes.length) {
        indexes[idxIdx] = trueStart + rem - 1;
        idxIdx++;
        trueStart--;
        if ((trueStart + rem) % byteLen == 0) {
          trueStart += (byteLen + rem + (lenght - idxIdx).remainder(byteLen));
          rem = (lenght - idxIdx).remainder(byteLen) == 0
              ? 8
              : (lenght - idxIdx).remainder(byteLen);
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
