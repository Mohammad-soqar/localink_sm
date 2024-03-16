import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/screens/messaging.dart';
import 'package:localink_sm/utils/colors.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Future<model.User?> getUser(String userId) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentSnapshot userSnapshot =
        await firestore.collection('users').doc(userId).get();
    if (userSnapshot.exists) {
      return model.User.fromSnap(userSnapshot);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF111b21),
      appBar: AppBar(
        backgroundColor: Color(0xFF2A2F32),
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Category selector
          Container(
            height: 90,
            color: Color(0xFF2A2F32),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                CategoryWidget(label: 'All Chats'),
                CategoryWidget(label: 'Personal'),
                CategoryWidget(label: 'Work'),
                CategoryWidget(label: 'Groups'),
              ],
            ),
          ),
          // Chat list
          Expanded(
            child: Container(
              child: ChatListWidget(),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryWidget extends StatelessWidget {
  final String label;

  const CategoryWidget({Key? key, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
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

  // Method to fetch user details from Firestore
  Future<model.User?> getUser(String userId) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentSnapshot userSnapshot =
        await firestore.collection('users').doc(userId).get();
    if (userSnapshot.exists) {
      return model.User.fromSnap(userSnapshot);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: _getUserFollowingList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No users found.'));
        }

        List<String> followingList = snapshot.data!;

        return ListView.builder(
          itemCount: followingList.length,
          itemBuilder: (BuildContext context, int index) {
            return FutureBuilder<model.User?>(
              future: getUser(followingList[index]),
              builder: (context, AsyncSnapshot<model.User?> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    title: Text('Loading...',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                if (!userSnapshot.hasData) {
                  return const ListTile(
                    title: Text('User not found',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                model.User user = userSnapshot.data!;

                return FutureBuilder<Map<String, dynamic>>(
                  future: _firestoreMethods.getOrCreateConversation(
                      [FirebaseAuth.instance.currentUser!.uid, user.uid]),
                  builder: (context, conversationSnapshot) {
                    if (conversationSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const ListTile(
                          title: Text('Loading...',
                              style: TextStyle(color: Colors.grey)));
                    }

                    if (!conversationSnapshot.hasData) {
                      return const ListTile(
                          title: Text('Unable to load conversation',
                              style: TextStyle(color: Colors.grey)));
                    }

                    String conversationId =
                        conversationSnapshot.data!['conversationId'];
                    String lastMessage =
                        conversationSnapshot.data!['lastMessage'] ?? 'Say hi!';

                    // Add the snippet here to calculate the unreadCount
                    int unreadCount = 0; // Default to 0

                    Map<String, dynamic>? unreadCountsMap = conversationSnapshot
                        .data!['unreadCounts'] as Map<String, dynamic>?;

                    if (unreadCountsMap != null &&
                        unreadCountsMap.containsKey(
                            FirebaseAuth.instance.currentUser!.uid)) {
                      unreadCount = unreadCountsMap[
                              FirebaseAuth.instance.currentUser!.uid] as int? ??
                          0;
                    }
                    // End of the added snippet

                    return ChatItemWidget(
                      contactName: user.username,
                      avatarUrl: user.photoUrl,
                      lastMessage: lastMessage,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MessagePage(
                                user: user, conversationId: conversationId),
                          ),
                        );
                      },
                      unreadCount:
                          unreadCount, // Pass the unread count to the ChatItemWidget
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
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

class ChatItemWidget extends StatelessWidget {
  final String contactName;
  final String avatarUrl;
  final String lastMessage;
  final VoidCallback onTap;
  final int? unreadCount; // Add this line

  const ChatItemWidget({
    Key? key,
    required this.contactName,
    required this.avatarUrl,
    required this.lastMessage,
    required this.onTap,
    this.unreadCount, // Add this line
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          backgroundColor: avatarUrl.isEmpty ? Colors.grey : null,
        ),
        title: Text(
          contactName,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          lastMessage,
          style: TextStyle(
            color:unreadCount != null && unreadCount! > 0
                ? primaryColor
                : Colors.grey[400]
            
             ,
            fontWeight: unreadCount != null && unreadCount! > 0
                ? FontWeight.w600
                : FontWeight
                    .normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: unreadCount != null && unreadCount! > 0
            ? Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: highlightColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unreadCount',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              )
            : null, // Display the unread count here
      ),
    );
  }
}
