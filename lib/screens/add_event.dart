// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
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
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class AddEventPage extends StatefulWidget {
  const AddEventPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AddEventPageState createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final PageController _pageController = PageController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationDetailsController = TextEditingController();
  final _radiusController = TextEditingController();
  final _attendenceController = TextEditingController();
  DateTime? _selectedDateTime;
  mapbox.LatLng? _pickedLocation;
  Color _pinColor = highlightColor2;
  final String organizer = "ErrorWithGettingTheUserId";
  final List<XFile> _selectedImages = [];

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Add a loading state
  bool _isLoading = false;

  // Add a list to keep track of extra fields
  final List<Map<String, dynamic>> _extraFields = [];

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
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
    final List<File> compressedImages = [];

    for (var image in _selectedImages) {
      File? originalFile = await xFileToFile(image);
      File? mediaFile = await compressImage(originalFile!);
      compressedImages.add(mediaFile!);
    }

    for (var image in compressedImages) {
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

  String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2)}';
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

    setState(() {
      _isLoading = true;
    });

    try {
      String pinUrl = await _generatePinImage(uid, photoUrl);
      List<String> imageUrls = await _uploadImages(uid);
      String hexColor = colorToHex(_pinColor);

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
        pinUrl: pinUrl,
        pinColor: hexColor,
        imageUrls: imageUrls,
        maxAttendees: int.parse(_attendenceController.text),
        extraFields: _extraFields, // Include extra fields
      );

      if (!_isValidEvent(event)) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event validation failed')));
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('verifyEventContent');
      final response = await callable.call(<String, dynamic>{
        'description': event.description,
        'imageUrls': event.imageUrls,
      });

      if (response.data['approved']) {
        await addEvent(event);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Event rejected: ${response.data['reason']}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error verifying event: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isValidEvent(Event event) {
    if (event.name.isEmpty || event.description.isEmpty) return false;
    if (event.dateTime.isBefore(DateTime.now())) return false;
    if (event.latitude < -90 || event.latitude > 90) return false;
    if (event.longitude < -180 || event.longitude > 180) return false;
    if (event.radius <= 0) return false;
    if (_attendenceController.text.isEmpty) return false;

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
      const size = Size(150, 150); // Adjust size as needed

      // Draw the logo in the center
      const logoSize = Size(150, 150); // Adjust logo size as needed
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
          title: const Text('Pick Pin Color'),
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
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _addExtraField() {
    setState(() {
      _extraFields.add({'type': 'text', 'label': '', 'value': ''});
    });
  }

  void _removeExtraField(int index) {
    setState(() {
      _extraFields.removeAt(index);
    });
  }

  void _updateExtraField(int index, String label, String value) {
    setState(() {
      _extraFields[index]['label'] = label;
      _extraFields[index]['value'] = value;
    });
  }

  void _updateExtraFieldType(int index, String type) {
    setState(() {
      _extraFields[index]['type'] = type;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Event'),
        backgroundColor: highlightColor2, // Use your foregroundColor color
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStepOne(),
              _buildStepTwo(),
              _buildStepThree(),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepOne() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Event Name',
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: highlightColor2), // Use your foregroundColor color
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Event Description',
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: highlightColor2), // Use your foregroundColor color
              ),
            ),
            keyboardType: TextInputType.multiline,
            maxLines:
                null, // This allows the TextField to grow vertically as needed
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedDateTime == null
                      ? 'No Date Chosen!'
                      : 'Picked Date: ${_selectedDateTime.toString()}',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: _pickDateTime,
                style: TextButton.styleFrom(
                  foregroundColor:
                      highlightColor2, // Use your foregroundColor color
                ),
                child: const Text('Choose Date'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor:
                  highlightColor2, // Use your foregroundColor color
              backgroundColor: Colors.white,
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTwo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Text(
                'Pick Location on Map:',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _pickLocation,
                style: ElevatedButton.styleFrom(
                  foregroundColor:
                      highlightColor2, // Use your foregroundColor color
                  backgroundColor: Colors.white,
                ),
                child: const Text('Pick Location on Map'),
              ),
            ],
          ),
          if (_pickedLocation != null) ...[
            const SizedBox(height: 10),
            Text(
              'Selected Location: ${_pickedLocation!.latitude}, ${_pickedLocation!.longitude}',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Text(
                'Pick Your Color:',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _pickColor,
                    style: ElevatedButton.styleFrom(
                      foregroundColor:
                          highlightColor2, // Use your foreground color
                      backgroundColor: Colors.white,
                    ),
                    child: const Text('Pick Color'),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    children: [
                      Text(' ${_pinColor.toHexStringRGB()}'), 
                      const SizedBox(width: 10),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _pinColor,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _pickImages,
            style: ElevatedButton.styleFrom(
              foregroundColor:
                  highlightColor2, // Use your foregroundColor color
              backgroundColor: Colors.white,
            ),
            child: const Text('Pick Images'),
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('${_selectedImages.length} images selected'),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _locationDetailsController,
            decoration: const InputDecoration(
              labelText: 'Location Details',
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: highlightColor2), // Use your foregroundColor color
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _radiusController,
            decoration: const InputDecoration(
              labelText: 'Radius (meters)',
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: highlightColor2), // Use your foregroundColor color
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _attendenceController,
            decoration: const InputDecoration(
              labelText: 'Max Attendance',
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: highlightColor2), // Use your foregroundColor color
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor:
                      highlightColor2, // Use your foregroundColor color
                  backgroundColor: Colors.white,
                ),
                child: const Text('Previous'),
              ),
              ElevatedButton(
                onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: highlightColor2,
                ),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepThree() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'Extra Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _extraFields.length,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (value) => _updateExtraField(
                                index, value, _extraFields[index]['value']),
                            decoration: const InputDecoration(
                              labelText: 'Field Label',
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color:
                                        highlightColor2), // Use your foregroundColor color
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: _extraFields[index]['type'],
                          onChanged: (value) =>
                              _updateExtraFieldType(index, value!),
                          items: const [
                            DropdownMenuItem(
                              value: 'text',
                              child: Text('Text'),
                            ),
                            DropdownMenuItem(
                              value: 'number',
                              child: Text('Number'),
                            ),
                            DropdownMenuItem(
                              value: 'date',
                              child: Text('Date'),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeExtraField(index),
                        ),
                      ],
                    ),
                    if (_extraFields[index]['type'] == 'text') ...[
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (value) => _updateExtraField(
                            index, _extraFields[index]['label'], value),
                        decoration: InputDecoration(
                          labelText: _extraFields[index]['label'],
                          border: const OutlineInputBorder(),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                                color:
                                    highlightColor2), // Use your foregroundColor color
                          ),
                        ),
                      ),
                    ] else if (_extraFields[index]['type'] == 'number') ...[
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (value) => _updateExtraField(
                            index, _extraFields[index]['label'], value),
                        decoration: InputDecoration(
                          labelText: _extraFields[index]['label'],
                          border: const OutlineInputBorder(),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                                color:
                                    highlightColor2), // Use your foregroundColor color
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ] else if (_extraFields[index]['type'] == 'date') ...[
                      const SizedBox(height: 10),
                      TextField(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            _updateExtraField(
                                index,
                                _extraFields[index]['label'],
                                pickedDate.toString());
                          }
                        },
                        decoration: InputDecoration(
                          labelText: _extraFields[index]['label'],
                          border: const OutlineInputBorder(),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                                color:
                                    highlightColor2), // Use your foregroundColor color
                          ),
                        ),
                        readOnly: true,
                        controller: TextEditingController(
                            text: _extraFields[index]['value']),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _addExtraField,
            style: ElevatedButton.styleFrom(
              foregroundColor:
                  highlightColor2, // Use your foregroundColor color
              backgroundColor: Colors.white,
            ),
            child: const Text('Add Field'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              final model.User? user =
                  Provider.of<UserProvider>(context, listen: false).getUser;
              if (user != null) {
                _submitEvent(user.uid, user.photoUrl);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User not logged in')));
              }
            },
            style: ElevatedButton.styleFrom(
              foregroundColor:
                  highlightColor2, // Use your foregroundColor color
              backgroundColor: Colors.white,
            ),
            child: const Text('Submit Event'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor:
                  highlightColor2, // Use your foregroundColor color
              backgroundColor: Colors.white,
            ),
            child: const Text('Previous'),
          ),
        ],
      ),
    );
  }
}
