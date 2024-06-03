import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:localink_sm/models/event.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/providers/user_provider.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/widgets/new_map_picker.dart';
import 'package:mapbox_gl/mapbox_gl.dart' as mapbox;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
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
  mapbox.LatLng? _pickedLocation;
  Color _pinColor = highlightColor; // Default pin color
  final String organizer = "ErrorWithGettingTheUserId";
  final List<XFile> _selectedImages = [];

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage();

    if (images != null && images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

 Future<File?> xFileToFile(XFile xfile) async {
    return File(xfile.path);
  }

  Future<List<String>> _uploadImages(String uid) async {
    List<String> imageUrls = [];
    final List<File> _compressedImages = [];

    for(var image in _selectedImages){
      File? originalFile = await xFileToFile(image);
      File? mediaFile = await compressImage(originalFile!);
      _compressedImages.add(mediaFile!);
    }

    for (var image in _compressedImages) {
      final ref = _storage.ref().child(
          'eventImages/$uid/${DateTime.now().millisecondsSinceEpoch}.png');
      final uploadTask = await ref.putFile(File(image.path));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      imageUrls.add(downloadUrl);
    }

    return imageUrls;
  }

  Future<File?> compressImage(File file) async {
    try {
      final directory = await getTemporaryDirectory();
      final targetPath =
          '${directory.absolute.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

      final XFile? xFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 88,
        minWidth: 1000,
        minHeight: 1000,
      );

      if (xFile != null) {
        return File(xFile.path);
      }
      return null;
    } catch (e) {
      print("Error during image compression: $e");
      return null;
    }
  }

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

    List<String> imageUrls = await _uploadImages(uid);

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
      imageUrls: imageUrls, // Store the image URLs
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
          onLocationPicked: (mapbox.LatLng location) {
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
      final size = Size(150, 150); // Adjust size as needed

      // Draw the logo in the center
      final logoSize = Size(150, 150); // Adjust logo size as needed
      final Rect logoRect =
          Rect.fromLTWH(0, 0, logoSize.width, logoSize.height);

      canvas.drawImageRect(
          image,
          Rect.fromLTRB(0, 0, image.width.toDouble(), image.height.toDouble()),
          logoRect,
          Paint());

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
              keyboardType: TextInputType.multiline,
              maxLines:
                  null, // This allows the TextField to grow vertically as needed
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
              onPressed: _pickImages,
              child: Text('Pick Images'),
            ),
            if (_selectedImages.isNotEmpty) ...[
              SizedBox(height: 10),
              Text('${_selectedImages.length} images selected'),
            ],
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
