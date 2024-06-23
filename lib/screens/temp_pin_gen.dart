
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/models/user.dart' as model;

class GeneratePinsScreen extends StatefulWidget {
  @override
  _GeneratePinsScreenState createState() => _GeneratePinsScreenState();
}

class _GeneratePinsScreenState extends State<GeneratePinsScreen> {
  bool _isLoading = false;

  Future<ui.Image> loadImageFromAssets(String assetPath) async {
    ByteData data = await rootBundle.load(assetPath);
    Uint8List bytes = data.buffer.asUint8List();
    return loadImageFromBytes(bytes);
  }

  Future<ui.Image> loadImageFromBytes(Uint8List bytes) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      return completer.complete(img);
    });
    return completer.future;
  }

  Future<void> createPins(Uint8List profileImage, String userId) async {
    // Load the pin SVG
    ui.Image pinImage = await loadImageFromAssets('assets/icons/mappin22.png');
    ui.Image userImage = await loadImageFromBytes(profileImage);
    Uint8List normalPin = await createCustomMarkerImage(pinImage, userImage);
    Uint8List bluePin = await createCustomMarkerImage(pinImage, userImage);

    // Save pins to Firebase Storage
    await _uploadPinToStorage(normalPin, 'normal_pin.png', userId);
    await _uploadPinToStorage(bluePin, 'blue_pin.png', userId);
  }

  Future<Uint8List> createCustomMarkerImage(
      ui.Image pinImage, ui.Image userImage) async {
    final double imageSize = pinImage.width / 2;
    final Offset imageOffset = Offset((pinImage.width - imageSize) / 2,
        (pinImage.height/1.65 - imageSize) / 2 - 15);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint();

    canvas.drawImage(pinImage, Offset.zero, paint);

    final Rect ovalRect = Rect.fromCircle(
        center: imageOffset + Offset(imageSize / 2, imageSize / 2),
        radius: imageSize / 2);
    final Path ovalPath = Path()..addOval(ovalRect);
    canvas.clipPath(ovalPath, doAntiAlias: false);
    canvas.drawImageRect(
        userImage,
        Rect.fromLTRB(
            0, 0, userImage.width.toDouble(), userImage.height.toDouble()),
        ovalRect,
        paint);

    final ui.Image compositeImage =
        await recorder.endRecording().toImage(pinImage.width, pinImage.height);

    final ByteData? byteData =
        await compositeImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _uploadPinToStorage(Uint8List pinImage, String fileName, String userId) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath)..writeAsBytesSync(pinImage);

    // Use the user's ID to create a unique folder for each user
    await FirebaseStorage.instance.ref('user_pins/$userId/$fileName').putFile(file);
  }

  void generatePinsForOldUsers() async {
    setState(() {
      _isLoading = true;
    });

    // Fetch old users from Firestore
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('users').get();

    for (QueryDocumentSnapshot doc in querySnapshot.docs) {
      String userId = doc.id;
      model.User user = model.User.fromSnap(doc);
      
      if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
        // Download the user's profile picture
        final profileImageBytes = (await NetworkAssetBundle(Uri.parse(user.photoUrl!)).load(user.photoUrl!)).buffer.asUint8List();

        // Create and upload pins
        await createPins(profileImageBytes, userId);
      }
    }

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pins generated for all users.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Generate Pins for Old Users'),
      ),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : ElevatedButton(
                onPressed: generatePinsForOldUsers,
                child: Text('Generate Pins'),
              ),
      ),
    );
  }
}
