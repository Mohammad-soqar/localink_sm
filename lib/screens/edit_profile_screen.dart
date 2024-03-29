import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

import 'package:localink_sm/resources/storage_methods.dart';

class EditProfilePage extends StatefulWidget {
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  late model.User _currentUser;
  bool _isUsernameEditable = true;
  bool _isEmailEditable = true;
  String _userPhotoUrl = '';
  var userData = {};

  File? _image;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    getCurrentUser();
  }

  Future<void> getCurrentUser() async {
    User? firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      model.User currentUser = model.User.fromSnap(userSnapshot);

      setState(() {
        _currentUser = currentUser;
        _usernameController.text = _currentUser.username;
        _emailController.text = _currentUser.email;
        _phoneController.text = _currentUser.phonenumber;
        _userPhotoUrl = _currentUser.photoUrl;
        _isUsernameEditable =
            canUsernameBeEdited(_currentUser.lastUsernameChangeDate);
        _isEmailEditable = canEmailBeEdited(_currentUser.emailChangeCount);
      });
    }
  }

  bool canUsernameBeEdited(DateTime? lastChanged) {
    if (lastChanged == null) return true;
    final daysSinceLastChange = DateTime.now().difference(lastChanged).inDays;
    return daysSinceLastChange >= 30;
  }

  bool canEmailBeEdited(int changeCount) {
    return changeCount < 3;
  }

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> saveProfileChanges() async {
    // Assuming _currentUser is your current user object
    User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      showSnackBar("User not found. Please login again.", context);
      return;
    }

    DocumentReference userDocRef =
        FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);

    Map<String, dynamic> updates = {};

    // Check for username changes and constraints
    if (_usernameController.text.trim() != _currentUser.username &&
        canUsernameBeEdited(_currentUser.lastUsernameChangeDate)) {
      updates['username'] = _usernameController.text.trim();
      updates['lastUsernameChangeDate'] = Timestamp.now();
    }

    // Check for email changes and constraints
    if (_emailController.text.trim() != _currentUser.email &&
        canEmailBeEdited(_currentUser.emailChangeCount)) {
      updates['email'] = _emailController.text.trim();
      updates['emailChangeCount'] = FieldValue.increment(1);
      updates['emailChangeDates'] = FieldValue.arrayUnion([Timestamp.now()]);
    }

    // Check for phone number changes
    if (_phoneController.text.trim() != _currentUser.phonenumber) {
      updates['phonenumber'] = _phoneController.text.trim();
    }

    // Upload new profile picture if selected
    if (_image != null) {
      Uint8List imageData = await _image!.readAsBytes();

      // Assuming the old image's path is stored in the user's 'photoUrl' field
      String? oldImageUrl = _currentUser.photoUrl;

      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        // Delete the old image from Firebase Storage
        try {
          await deleteImageFromStorage(oldImageUrl);
        } catch (e) {
          showSnackBar("Failed to delete old image: $e", context);
          // Optionally, return if you want to halt the update when deletion fails
          return;
        }
      }

      // Upload the new image and update the user's profile
      try {
        String imageUrl = await StorageMethods()
            .uploadImageToStorage('profile_pictures', imageData, false);
        updates['photoUrl'] = imageUrl;
      } catch (e) {
        showSnackBar("Failed to upload new image: $e", context);
        return;
      }
    }

    // Apply updates if any
    if (updates.isNotEmpty) {
      try {
        await userDocRef.update(updates);
        showSnackBar("Profile updated successfully!", context);
      } catch (e) {
        showSnackBar("Error updating profile: $e", context);
      }
    } else {
      showSnackBar("No changes detected.", context);
    }
  }

  Future<void> deleteImageFromStorage(String imageUrl) async {
    final FirebaseStorage storage = FirebaseStorage.instance;

    String? storagePath = imageUrl.split('?').first;
    storagePath = storagePath.split('o/').last;
    storagePath = Uri.decodeComponent(storagePath);

    try {
      Reference ref = storage.ref().child(storagePath);
      await ref.delete();
      print("Old image deleted successfully.");
    } catch (e) {
      print("Error deleting old image: $e");
      throw e; 
    }
  }

  void showSnackBar(String content, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(content)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: saveProfileChanges,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: <Widget>[
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey.shade800,
            child: ClipOval(
              child: _image != null
                  ? Image.file(
                      _image!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    )
                  : _userPhotoUrl.isNotEmpty
                      ? Image.network(
                          _userPhotoUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.person, color: Colors.white, size: 80),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: 'Username'),
            enabled: _isUsernameEditable,
          ),
          SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(labelText: 'Email'),
            enabled: _isEmailEditable,
          ),
          SizedBox(height: 20),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(labelText: 'Phone Number'),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: pickImage,
            child: Text('Change Profile Picture'),
          ),
        ],
      ),
    );
  }
}
