import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'package:localink_sm/models/event.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/providers/user_provider.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/widgets/new_map_picker.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class AddEventPage extends StatefulWidget {
  @override
  _AddEventPageState createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationDetailsController = TextEditingController();
  final _radiusController = TextEditingController();
  DateTime? _selectedDateTime;
  LatLng? _pickedLocation;
  Color _pinColor = highlightColor; // Default pin color
  final String organizer = "ErrorWithGettingTheUserId";
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> _submitEvent(String uid, String photoUrl) async {
    if (_pickedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please pick a location')));
      return;
    }

    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please pick a date and time')));
      return;
    }

    // Generate pin image with the selected color and logo
    String pinUrl = await _generatePinImage(uid, photoUrl);

    final event = Event(
      id: FirebaseFirestore.instance.collection('events').doc().id,
      name: _nameController.text,
      description: _descriptionController.text,
      dateTime: _selectedDateTime!,
      latitude: _pickedLocation!.latitude,
      longitude: _pickedLocation!.longitude,
      organizer: uid,
      locationDetails: _locationDetailsController.text,
      attendees: [],
      radius: double.parse(_radiusController.text),
      pinUrl: pinUrl, // Store the pin image URL
    );

    if (_isValidEvent(event)) {
      await addEvent(event);
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event validation failed')));
    }
  }

  bool _isValidEvent(Event event) {
    if (event.name.isEmpty || event.description.isEmpty) return false;
    if (event.dateTime.isBefore(DateTime.now())) return false;
    if (event.latitude < -90 || event.latitude > 90) return false;
    if (event.longitude < -180 || event.longitude > 180) return false;
    return true;
  }

  Future<void> addEvent(Event event) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .set(event.toJson());
      print("Event added successfully!");
    } catch (e) {
      print("Error adding event: $e");
    }
  }

  void _pickLocation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          onLocationPicked: (LatLng location) {
            setState(() {
              _pickedLocation = location;
            });
          },
        ),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<String> _generatePinImage(String uid, String photoUrl) async {
    final http.Response response = await http.get(Uri.parse(photoUrl));
    if (response.statusCode == 200) {
      final Uint8List logoBytes = response.bodyBytes;
      final codec = await ui.instantiateImageCodec(logoBytes);
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = _pinColor;
      final size = Size(100, 100); // Adjust size as needed

      // Draw the pin background
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), size.width / 2, paint);

      // Draw the logo in the center
      final logoSize = Size(50, 50); // Adjust logo size as needed
      final logoOffset = Offset((size.width - logoSize.width) / 2,
          (size.height - logoSize.height) / 2);
      paint.isAntiAlias = true;
      canvas.drawImageRect(
          image,
          Rect.fromLTRB(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(
              logoOffset.dx, logoOffset.dy, logoSize.width, logoSize.height),
          paint);

      final picture = recorder.endRecording();
      final img =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final ref = _storage
          .ref()
          .child('pins/$uid/${DateTime.now().millisecondsSinceEpoch}.png');
      await ref.putData(pngBytes);
      return await ref.getDownloadURL();
    } else {
      throw Exception('Failed to load logo image');
    }
  }

  void _pickColor() {
    Color currentColor = _pinColor;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pick Pin Color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) {
                currentColor = color;
              },
              showLabel: true,
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              displayThumbColor: true,
              hexInputBar: true, // Enable hex input bar
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _pinColor = currentColor;
                });
                Navigator.of(context).pop();
              },
              child: Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final model.User? user = Provider.of<UserProvider>(context).getUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Event'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Event Name'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Event Description'),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDateTime == null
                        ? 'No Date Chosen!'
                        : 'Picked Date: ${_selectedDateTime.toString()}',
                  ),
                ),
                TextButton(
                  onPressed: _pickDateTime,
                  child: Text('Choose Date'),
                ),
              ],
            ),
            TextField(
              controller: _locationDetailsController,
              decoration: InputDecoration(labelText: 'Location Details'),
            ),
            TextField(
              controller: _radiusController,
              decoration: InputDecoration(labelText: 'Radius (meters)'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickLocation,
              child: Text('Pick Location on Map'),
            ),
            if (_pickedLocation != null) ...[
              Text(
                  'Selected Location: ${_pickedLocation!.latitude}, ${_pickedLocation!.longitude}'),
            ],
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Pin Color: ${_pinColor.toString()}'),
                ),
                ElevatedButton(
                  onPressed: _pickColor,
                  child: Text('Pick Color'),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                if (user != null) {
                  _submitEvent(user.uid, user.photoUrl);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('User not logged in')));
                }
              },
              child: Text('Add Event'),
            ),
          ],
        ),
      ),
    );
  }
}
