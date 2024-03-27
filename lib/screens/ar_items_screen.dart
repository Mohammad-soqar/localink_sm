import 'package:flutter/material.dart';

class ARViewPage extends StatefulWidget {
  @override
  _ARViewPageState createState() => _ARViewPageState();
}

class _ARViewPageState extends State<ARViewPage> {
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
      
    );
  }

  
}
