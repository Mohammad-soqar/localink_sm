import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/utils/colors.dart';

class MessagePage extends StatefulWidget {
  final model.User? user;
  final String conversationId;

  const MessagePage(
      {Key? key, required this.user, required this.conversationId})
      : super(key: key);

  @override
  _MessagePageState createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final TextEditingController _messageController = TextEditingController();
  final FireStoreMethods _firestoreMethods = FireStoreMethods();
  final ScrollController _scrollController = ScrollController();
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? conversationId;

  @override
  void initState() {
    super.initState();
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    conversationId =
        widget.conversationId.isEmpty ? null : widget.conversationId;
    if (conversationId != null) {
      _firestoreMethods.resetUnreadCount(conversationId!, currentUserId);
    }
  }

  Future<Map<String, dynamic>?> fetchPostDetails(String postId) async {
    try {
      DocumentSnapshot postSnapshot =
          await _firestore.collection('posts').doc(postId).get();
      if (postSnapshot.exists) {
        Map<String, dynamic>? postData =
            postSnapshot.data() as Map<String, dynamic>?;
        QuerySnapshot mediaSnapshot = await _firestore
            .collection('posts/$postId/postMedia')
            .limit(1)
            .get();
        if (mediaSnapshot.docs.isNotEmpty) {
          var mediaData =
              mediaSnapshot.docs.first.data() as Map<String, dynamic>?;
          String? mediaUrl = mediaData?['mediaUrl'] as String?;
          if (mediaUrl != null) {
            postData?['mediaUrl'] = mediaUrl;
          }
        }
        return postData;
      }
    } catch (e) {
      print("Error fetching post: $e");
    }
    return null;
  }

  List<dynamic> _processMessagesForDateSeparators(List<DocumentSnapshot> docs) {
    List<dynamic> processedItems = [];
    DateTime? previousMessageDate;

    for (var doc in docs) {
      final messageData = doc.data() as Map<String, dynamic>;
      final timestamp = messageData['timestamp'];
      final messageTimestamp =
          timestamp != null ? timestamp as Timestamp : Timestamp.now();

      final messageDate = messageTimestamp.toDate();
      final justDate =
          DateTime(messageDate.year, messageDate.month, messageDate.day);

      if (previousMessageDate == null ||
          justDate.isAfter(previousMessageDate)) {
        processedItems.add(justDate);
        previousMessageDate = justDate;
      }

      processedItems.add(doc);
    }

    return processedItems;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      try {
        List<String> participantIDs = [FirebaseAuth.instance.currentUser!.uid];
        if (widget.user != null) {
          participantIDs.add(widget.user!.uid);
        }

        // Fetch the sender's user data
        String currentUserId = FirebaseAuth.instance.currentUser!.uid;
        DocumentSnapshot senderSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        var senderData = senderSnapshot.data() as Map<String, dynamic>;
        String senderName = senderData['username'];

        // Check if the conversationId is empty
        String? newConversationId =
            conversationId == null ? null : conversationId;

        // Send the message
        newConversationId = await _firestoreMethods.sendMessage(
          conversationId: newConversationId,
          participantIDs: participantIDs,
          senderId: FirebaseAuth.instance.currentUser!.uid,
          messageText: _messageController.text.trim(),
          messageType: 'text',
        );

        setState(() {
          conversationId = newConversationId;
        });

        _messageController.clear();

        if (widget.user != null) {
          // Send notification to the recipient
          HttpsCallable callable = FirebaseFunctions.instance
              .httpsCallable('sendMessageNotification');
          await callable.call({
            'userId': widget.user!.uid, // The ID of the recipient
            'messageSenderId':
                FirebaseAuth.instance.currentUser!.uid, // The ID of the sender
            'messageSenderName': senderName, // The name of the sender
            'messageText':
                _messageController.text.trim(), // The text of the message
          });
        }

        _firestoreMethods.resetUnreadCount(conversationId!, currentUserId);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      } catch (e) {
        print(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            widget.user != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(widget.user!.photoUrl),
                  )
                : FutureBuilder<DocumentSnapshot>(
                    future: _firestore
                        .collection('conversations')
                        .doc(widget.conversationId)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator(
                          strokeWidth: 2.0,
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Icon(Icons.group);
                      }
                      Map<String, dynamic> data =
                          snapshot.data!.data() as Map<String, dynamic>;
                      return CircleAvatar(
                        backgroundImage:
                            NetworkImage(data['groupPhotoUrl'] ?? ''),
                      );
                    },
                  ),
            SizedBox(width: 8),
            widget.user != null
                ? Text(widget.user!.username)
                : FutureBuilder<DocumentSnapshot>(
                    future: _firestore
                        .collection('conversations')
                        .doc(widget.conversationId)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator(
                          strokeWidth: 2.0,
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Text('Group');
                      }
                      Map<String, dynamic> data =
                          snapshot.data!.data() as Map<String, dynamic>;
                      return Text(data['title'] ?? 'Group');
                    },
                  ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.conversationId.isEmpty
                ? Center(
                    child: _buildInitialMessage(),
                  )
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream:
                        _firestoreMethods.getMessages(widget.conversationId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                          ),
                        );
                      }

                      List<Map<String, dynamic>> docs = snapshot.data ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: _buildInitialMessage(),
                        );
                      }

                      List<dynamic> itemsWithSeparators =
                          _processMessagesForDateSeparators(
                              docs.reversed.cast<DocumentSnapshot<Object?>>().toList());
                      return _buildMessagesList(itemsWithSeparators);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildItem(dynamic item) {
    if (item is DocumentSnapshot) {
      Map<String, dynamic> messageData = item.data() as Map<String, dynamic>;
      bool isMe =
          messageData['senderID'] == FirebaseAuth.instance.currentUser!.uid;
      if (messageData['type'] == 'post') {
        return _buildPostMessageTile(messageData, isMe);
      } else {
        return _buildMessageTile(messageData, isMe);
      }
    } else if (item is DateTime) {
      return _buildDateSeparator(item);
    } else {
      return SizedBox.shrink();
    }
  }

  Widget _buildDateSeparator(DateTime date) {
    String formattedDate = DateFormat('MMM d, yyyy').format(date);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          formattedDate,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageTile(Map<String, dynamic> messageData, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? highlightColorMessages : darkLBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) // Show sender name only for received messages
              FutureBuilder<DocumentSnapshot>(
                future: _firestore
                    .collection('users')
                    .doc(messageData['senderID'])
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Text('Loading...',
                        style: TextStyle(color: Colors.white));
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Text('Unknown',
                        style: TextStyle(color: Colors.white));
                  }
                  model.User sender = model.User.fromSnap(snapshot.data!);
                  return Text(
                    sender.username,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            Text(
              messageData['content'] ?? "Message not available",
              style: TextStyle(color: Colors.white),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                DateFormat('hh:mm a')
                    .format((messageData['timestamp'] as Timestamp).toDate()),
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostMessageTile(Map<String, dynamic> messageData, bool isMe) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: fetchPostDetails(messageData['sharedPostId']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(
            strokeWidth: 2.0,
          );
        } else if (snapshot.hasError || !snapshot.hasData) {
          return Text('Error fetching post or post not found');
        } else {
          Map<String, dynamic>? postDetails = snapshot.data;
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isMe ? highlightColorMessages : darkLBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Shared Post:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  if (postDetails?['mediaUrl'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        postDetails!['mediaUrl'],
                        fit: BoxFit.cover,
                      ),
                    ),
                  SizedBox(height: 4),
                  Text(
                    postDetails?['caption'] ?? 'Caption not available',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildInitialMessage() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock,
          color: Colors.grey,
          size: 64,
        ),
        SizedBox(height: 16),
        Text(
          "Your messages are secured with end-to-end encryption.",
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          "Start a conversation by sending a message.",
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Expanded _buildMessagesList(List<dynamic> items) {
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildItem(items[index]);
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.photo_camera),
            onPressed: () {
              // Handle camera action
            },
          ),
          IconButton(
            icon: Icon(Icons.attach_file),
            onPressed: () {
              // Handle attachment action
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Message...',
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: sendMessage,
          ),
        ],
      ),
    );
  }
}
