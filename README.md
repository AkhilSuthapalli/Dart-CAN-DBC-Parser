# Dart CAN DBC Parser

The package helps to parse the CAN DBC file.

# Features

DBC parsing, CAN decoding, CAN encoding

# Usage

You can upload the file using [file_picker](https://pub.dev/packages/file_picker) to application and create bytes from the file selected

``` dart
FilePickerResult? result = await FilePicker.platform.pickFiles();
Uint8List bytes = result.files.first.bytes as Uint8List;
DBCDatabase can = await DBCDatabase.loadFromBytes(bytes);
```

When the signals are loaded, by default the min value is assigned to the signal.

To decode the CAN Message use
``` dart
DBCDatabase can = await DBCDatabase.loadFromBytes(bytes);

Uint8List messageBytes = Uint8List(10);
messageBytes.buffer.asByteData().setUint16(0, 849);
messageBytes.buffer.asByteData().setUint16(2, 0xFFFF);
messageBytes.buffer.asByteData().setUint16(4, 0xFFFF);
messageBytes.buffer.asByteData().setUint16(6, 0xFFFF);
messageBytes.buffer.asByteData().setUint16(8, 0xFFFF);
Map<String, num> decoded = can.decode(messageBytes);
```

To encode the CAN Message, update the signal value and use encodeMessage(canID).
Currently, it does not support for Multiplexed signals.
``` dart
can.can.database[849]?[signal_name]?.value = new_signal_value;
Uint8List encoded = can.encodeMessage(849);
```

## Thanks to

This package was made using

- [dart_dbc_parser](https://pub.dev/packages/dart_dbc_parser)
