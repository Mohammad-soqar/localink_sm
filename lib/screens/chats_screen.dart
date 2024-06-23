import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/screens/chat.dart';
import 'package:localink_sm/screens/create_group_screen.dart';
import 'package:localink_sm/screens/group_settings.dart';
import 'package:localink_sm/utils/colors.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundColor,
      appBar: AppBar(
        backgroundColor: secondaryColor,
        title: const Text('Chats'),
        actions: [
          //icons goes here
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(0.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search...',
                filled: true,
                fillColor: darkLBackgroundColor,
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                // Add search logic if needed
              },
            ),
          ),
          Expanded(
            child: ChatListWidget(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CreateGroupScreen(),
            ),
          );
        },
        child: Icon(Icons.group_add),
        backgroundColor: primaryColor,
      ),
    );
  }
}

class ChatListWidget extends StatelessWidget {
  final FireStoreMethods _firestoreMethods = FireStoreMethods();

  Stream<List<String>> _getUserFollowingList() async* {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    var userSnap =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    var followingList = userSnap.data()!['following'];
    yield List<String>.from(followingList);
  }

  Future<model.User?> getUser(String userId) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentSnapshot userSnapshot =
        await firestore.collection('users').doc(userId).get();
    if (userSnapshot.exists) {
      return model.User.fromSnap(userSnapshot);
    }
    return null;
  }

  Future<List<String>> getMemberPhotoUrls(List<String> memberIds) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    List<String> photoUrls = [];
    for (String memberId in memberIds) {
      DocumentSnapshot userSnapshot =
          await firestore.collection('users').doc(memberId).get();
      if (userSnapshot.exists) {
        photoUrls.add(userSnapshot['photoUrl'] ?? '');
      }
    }
    return photoUrls;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participantIDs',
              arrayContains: FirebaseAuth.instance.currentUser!.uid)
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No conversations found.'));
        }

        List<QueryDocumentSnapshot> conversations = snapshot.data!.docs;

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            var conversation = conversations[index];
            var data = conversation.data() as Map<String, dynamic>;
            String conversationId = conversation.id;
            String lastMessage = data['lastMessage'] ?? 'Say hi!';
            int unreadCount = data['unreadCounts']
                    [FirebaseAuth.instance.currentUser!.uid] ??
                0;
            bool isGroup = data['isGroup'] ?? false;
            String title = isGroup ? data['title'] : '';
            String avatarUrl = isGroup ? data['groupImageUrl'] ?? '' : '';

            return FutureBuilder<model.User?>(
              future: isGroup
                  ? null
                  : getUser(data['participantIDs'].firstWhere(
                      (id) => id != FirebaseAuth.instance.currentUser!.uid)),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    title: Text('Loading...',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                if (!isGroup &&
                    (!userSnapshot.hasData || userSnapshot.data == null)) {
                  return const ListTile(
                    title: Text('User not found',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                String contactName =
                    isGroup ? title : userSnapshot.data!.username;
                String contactAvatarUrl =
                    isGroup ? avatarUrl : userSnapshot.data!.photoUrl;
                List<String> memberPhotoUrls = [];

                if (isGroup) {
                  List<String> memberIds =
                      List<String>.from(data['participantIDs']);
                  return FutureBuilder<List<String>>(
                    future: getMemberPhotoUrls(memberIds),
                    builder: (context, memberSnapshot) {
                      if (memberSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const ListTile(
                          title: Text('Loading...',
                              style: TextStyle(color: Colors.grey)),
                        );
                      }

                      if (memberSnapshot.hasError || !memberSnapshot.hasData) {
                        return const ListTile(
                          title: Text('Members not found',
                              style: TextStyle(color: Colors.grey)),
                        );
                      }

                      memberPhotoUrls = memberSnapshot.data!;

                      return ChatItemWidget(
                        contactName: contactName,
                        avatarUrl: contactAvatarUrl,
                        lastMessage: lastMessage,
                        conversationId:conversationId,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => MessagePage(
                                  user: null, conversationId: conversationId),
                            ),
                          );
                        },
                        unreadCount: unreadCount,
                        isGroup: isGroup,
                        memberPhotoUrls: memberPhotoUrls,
                      );
                    },
                  );
                } else {
                  return ChatItemWidget(
                    contactName: contactName,
                    avatarUrl: contactAvatarUrl,
                    lastMessage: lastMessage,
                    conversationId: conversationId,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MessagePage(
                              user: userSnapshot.data,
                              conversationId: conversationId),
                        ),
                      );
                    },
                    unreadCount: unreadCount,
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}


class ChatItemWidget extends StatelessWidget {
  final String contactName;
  final String avatarUrl;
  final String lastMessage;
  final VoidCallback onTap;
  final int unreadCount;
  final bool isGroup;
  final List<String> memberPhotoUrls;
  final String conversationId;


  const ChatItemWidget({
    Key? key,
    required this.contactName,
    required this.avatarUrl,
    required this.lastMessage,
    required this.onTap,
    required this.unreadCount,
    this.isGroup = false,
    this.memberPhotoUrls = const [], required this.conversationId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(avatarUrl),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contactName,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    lastMessage,
                    style: TextStyle(color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isGroup)
              Container(
                width: 60, // Adjust as needed
                height: 30, // Adjust as needed
                child: Stack(
                  children: _buildGroupMemberAvatars(),
                ),
              ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              if(isGroup)
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GroupSettingsPage(conversationId: conversationId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupMemberAvatars() {
    List<Widget> avatars = [];
    int memberCount = memberPhotoUrls.length;

    for (int i = 0; i < memberCount && i < 3; i++) {
      avatars.add(
        Positioned(
          left: i * 20.0,
          child: CircleAvatar(
            backgroundImage: NetworkImage(memberPhotoUrls[i]),
            radius: 10,
          ),
        ),
      );
    }

    if (memberCount > 3) {
      avatars.add(
        Positioned(
          left: 3 * 20.0,
          child: CircleAvatar(
            backgroundColor: Colors.grey,
            radius: 10,
            child: Text(
              '+${memberCount - 3}',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      );
    }

    return avatars;
  }
}


Stream<List<String>> _getUserFollowingList() async* {
  String userId = FirebaseAuth.instance.currentUser!.uid;
  var userSnap =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
  var followingList = userSnap.data()!['following'];
  yield List<String>.from(followingList);
  print(followingList);
}
