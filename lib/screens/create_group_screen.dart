import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/widgets/custom_loading_indicator.dart'; // Import the custom loading indicator

class CreateGroupScreen extends StatefulWidget {
  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<String> _selectedParticipants = [];
  String? _groupImageUrl;
  File? _image;
  final picker = ImagePicker();

  Future<List<model.User>> _getFollowingList() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    var userSnap =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    var followingList = userSnap.data()!['following'];
    List<model.User> users = [];
    for (var userId in followingList) {
      var user = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (user.exists) {
        users.add(model.User.fromSnap(user));
      }
    }
    return users;
  }

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      String fileName = 'group_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageReference = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageReference.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  void _createGroup() async {
    if (_groupNameController.text.isNotEmpty && _selectedParticipants.isNotEmpty) {
      List<String> participantIDs = _selectedParticipants;
      participantIDs.add(FirebaseAuth.instance.currentUser!.uid);

      // Upload group image if available
      if (_image != null) {
        _groupImageUrl = await _uploadImage(_image!);
      }

      await FirebaseFirestore.instance.collection('conversations').add({
        'title': _groupNameController.text,
        'groupImageUrl': _groupImageUrl,
        'participantIDs': participantIDs,
        'participantsKey': participantIDs.join("_"),
        'isGroup': true,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCounts': {for (var id in participantIDs) id: 0}
      });

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Group'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: _image != null
                        ? FileImage(_image!)
                        : NetworkImage('https://cdn.pixabay.com/photo/2020/05/29/13/26/icons-5235125_1280.png') as ImageProvider,
                  ),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(labelText: 'Group Name'),
            ),
            SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<model.User>>(
                future: _getFollowingList(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CustomLoadingIndicator();
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text('No followers found.');
                  }
                  List<model.User> users = snapshot.data!;
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      model.User user = users[index];
                      return CheckboxListTile(
                        secondary: CircleAvatar(
                          backgroundImage: NetworkImage(user.photoUrl),
                        ),
                        title: Text(user.username),
                        value: _selectedParticipants.contains(user.uid),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedParticipants.add(user.uid);
                            } else {
                              _selectedParticipants.remove(user.uid);
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _createGroup,
              child: Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }
}
