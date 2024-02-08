import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:localink_sm/models/ARitem.dart';
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/utils/utils.dart';

class UploadARItemScreen extends StatefulWidget {
  @override
  _UploadARItemScreenState createState() => _UploadARItemScreenState();
}

class _UploadARItemScreenState extends State<UploadARItemScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  Uint8List? _imageFile;
  bool _isLoading = false;
  GeoPoint? _location;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndSetImage() async {
    final imageBytes = await pickImage(ImageSource.gallery);
    if (imageBytes != null) {
      setState(() {
        _imageFile = imageBytes;
      });
    }
  }

  Future<void> _uploadARItem() async {
    if (_imageFile == null ||
        _nameController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('All fields are required')));
      return;
    }
    setState(() => _isLoading = true);

    // Dummy data for location, replace with actual location fetching logic
    _location = GeoPoint(41.0488, 28.9517); // Replace with actual location

    // Replace with your method to upload AR item
    String result = await FireStoreMethods().uploadARItem(
      _nameController.text,
      _descriptionController.text,
      _location!,
      _imageFile!,
      ItemType.common, // Enum for item type, replace with actual logic
    );

    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload AR Item')),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Item Name')),
              TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(labelText: 'Description')),
              SizedBox(height: 10),
              _imageFile != null
                  ? Image.memory(_imageFile!, height: 150)
                  : ElevatedButton(
                      onPressed: _pickAndSetImage, child: Text('Select Image')),
              SizedBox(height: 20),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _uploadARItem, child: Text('Upload AR Item')),
            ],
          ),
        ),
      ),
    );
  }
}
