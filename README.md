# Dart DBC Parser for web

The package helps to parse the CAN DBC file for web.

# Features

DBC parsing, CAN decoding

# Usage

Web natively doesn't support File (dart:io is not supported in Web). You can make use of this package to create CAN Database and decode CAN messages.

You can upload the file using [file_picker](https://pub.dev/packages/file_picker) to web application and create bytes from the file selected

```dart
FilePickerResult? result = await FilePicker.platform.pickFiles();
Uint8List bytes = result.files.first.bytes as Uint8List;
DBCDatabase can = await DBCDatabase.loadFromBytes(bytes);
```


## Thanks to

This package was made using

- [dart_dbc_parser](https://pub.dev/packages/dart_dbc_parser)
