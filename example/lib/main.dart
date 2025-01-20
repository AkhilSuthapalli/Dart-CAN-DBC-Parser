import 'package:can_dbc_parser/can_dbc_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter CAN DBC Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'FlutterCAN DBC Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  late DBCDatabase can;

  @override
  void initState(){
    super.initState();
    loadCAN();
  }

  void loadCAN() async{
    var rootBundleFile = await rootBundle.load("assets/sample.dbc");
    can = await DBCDatabase.loadFromBytes(rootBundleFile.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: (){
              var signal = Uint8List.fromList([5, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
              Map<String, num> decodedString = can.decode(signal);
              print(decodedString);
              /// returns
              /// {FuelLevel: 0}
            },
            child: Text("Decode Signal"),
          ),
          ElevatedButton(
            onPressed: (){
              var signal = can.encodeMessage(1280);
              print(signal);
              /// returns
              /// [5, 0, 0, 0, 0, 0, 0, 0, 0, 0]
              /// min value is considered as default for the signals

            },
            child: Text("Encode Signal"),
          ),
          ElevatedButton(
            onPressed: (){
              var value = can.database[1280]!["FuelLevel"]?.value;
              print(value);
              /// returns 0
              /// if ran after update value
              /// you'll get 4
              /// If you do encoding
              /// will lead to [5, 0, 4, 0, 0, 0, 0, 0, 0, 0]
            },
            child: Text("Get Value"),
          ),
          ElevatedButton(
            onPressed: (){
              double newValue = 4;
              can.database[1280]!["FuelLevel"]?.value = newValue;
            },
            child: Text("Update Value"),
          ),
          ElevatedButton(
            onPressed: (){
              print(can.valueTable);
              /// returns
              /// {SideStandStatus: {1: DOWN, 0: UP}}
            },
            child: Text("Print value table"),
          ),
        ],
      )
    );
  }
}
