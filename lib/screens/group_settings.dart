import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/utils/colors.dart';

class GroupSettingsPage extends StatefulWidget {
  final String conversationId;

  const GroupSettingsPage({Key? key, required this.conversationId}) : super(key: key);

  @override
  _GroupSettingsPageState createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<String> _selectedParticipants = [];
  String? _groupImageUrl;
  File? _image;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadGroupDetails();
  }

  Future<void> _loadGroupDetails() async {
    DocumentSnapshot groupSnapshot = await FirebaseFirestore.instance.collection('conversations').doc(widget.conversationId).get();
    Map<String, dynamic> groupData = groupSnapshot.data() as Map<String, dynamic>;
    setState(() {
      _groupNameController.text = groupData['title'];
      _groupImageUrl = groupData['groupImageUrl'];
      _selectedParticipants.addAll(List<String>.from(groupData['participantIDs']));
    });
  }

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      // Upload the image to Firebase Storage and get the URL
      String imageUrl = await _uploadGroupImage(_image!);
      setState(() {
        _groupImageUrl = imageUrl;
      });
    }
  }

  Future<String> _uploadGroupImage(File image) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    String filePath = 'group_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    UploadTask uploadTask = FirebaseStorage.instance.ref().child(filePath).putFile(image);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<List<model.User>> _getFollowingList() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    var userSnap = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    var followingList = userSnap.data()!['following'];
    List<model.User> users = [];
    for (var userId in followingList) {
      var user = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (user.exists) {
        users.add(model.User.fromSnap(user));
      }
    }
    return users;
  }

  void _updateGroup() async {
    if (_groupNameController.text.isNotEmpty && _selectedParticipants.isNotEmpty) {
      await FirebaseFirestore.instance.collection('conversations').doc(widget.conversationId).update({
        'title': _groupNameController.text,
        'groupImageUrl': _groupImageUrl,
        'participantIDs': _selectedParticipants,
        'participantsKey': _selectedParticipants.join("_"),
      });
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_groupImageUrl != null)
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(_groupImageUrl!),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                    icon: Icon(Icons.edit, color: Colors.white),
                    onPressed: pickImage,
                  ),
                ),
              )
            else
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey,
                child: IconButton(
                  icon: Icon(Icons.add_a_photo, color: Colors.white),
                  onPressed: pickImage,
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
                    return Center(child: CircularProgressIndicator());
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
                        title: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(user.photoUrl),
                              radius: 15,
                            ),
                            SizedBox(width: 8),
                            Text(user.username),
                          ],
                        ),
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
              onPressed: _updateGroup,
              child: Text('Update Group'),
            ),
          ],
        ),
      ),
    );
  }
}
