import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:flutter/material.dart';

class ARViewPage extends StatefulWidget {
  @override
  _ARViewPageState createState() => _ARViewPageState();
}

class _ARViewPageState extends State<ARViewPage> {
  late ArFlutterPlugin arCoreController;

  @override
  void initState() {
    super.initState();
    // Initialize AR session here
  }

  @override
  void dispose() {
    // Remember to dispose of the AR controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AR View'),
      ),
      body: ARView(
        onARViewCreated: _onArViewCreated(arCoreController),
        
      ),
    );
  }

   _onArViewCreated(ArFlutterPlugin arCoreController) {
    this.arCoreController = arCoreController;
    // Setup AR session options here
  }
}
