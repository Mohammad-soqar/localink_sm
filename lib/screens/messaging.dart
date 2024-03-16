import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/utils/colors.dart';

class MessagePage extends StatefulWidget {
  final model.User user;
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

  Future<Map<String, dynamic>> _getConversationId() async {
    String senderId = FirebaseAuth.instance.currentUser!.uid;
    String receiverId = widget.user.uid;
    return await _firestoreMethods
        .getOrCreateConversation([senderId, receiverId]);
  }

  @override
  void initState() {
    super.initState();
    // Add a listener to scroll to bottom whenever the messages list updates
     String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  _firestoreMethods.resetUnreadCount(widget.conversationId, currentUserId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  List<dynamic> _processMessagesForDateSeparators(List<DocumentSnapshot> docs) {
    List<dynamic> processedItems = [];
    DateTime? previousMessageDate;

    for (var doc in docs) {
      final messageData = doc.data() as Map<String, dynamic>;

      // Safely obtain the timestamp, handling possible null values
      final timestamp = messageData['timestamp'];
      final messageTimestamp = timestamp != null
          ? timestamp as Timestamp
          : Timestamp.now(); // Fallback to current time if null

      final messageDate = messageTimestamp.toDate();
      final justDate =
          DateTime(messageDate.year, messageDate.month, messageDate.day);

      if (previousMessageDate == null ||
          justDate.isAfter(previousMessageDate)) {
        processedItems.add(justDate); // Add a DateTime object as a separator
        previousMessageDate = justDate;
      }

      processedItems.add(doc); // Add the message document
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
        String receiverUserId = widget.user
            .uid; // Placeholder, replace with the actual receiver's user ID
        String?
            existingConversationId; // This should be set if there's an existing conversation selected

        // Attempt to send the message. If existingConversationId is null, getOrCreateConversation will handle creating a new one.
        await _firestoreMethods.sendMessage(
          conversationId:
              existingConversationId, // If this is null, a new conversation will be created
          participantIDs: [
            FirebaseAuth.instance.currentUser!.uid,
            receiverUserId
          ], // Required for creating a new conversation
          senderId: FirebaseAuth.instance.currentUser!.uid,
          messageText: _messageController.text.trim(),
          messageType: 'text', // Indicating that this is a text message
        );
        _messageController.clear();
      } catch (e) {
        print(e); // Ideally, use a more user-friendly way to show the error
      }
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(widget.user.photoUrl),
          ),
          SizedBox(width: 8),
          Text(widget.user.username),
        ],
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: widget.conversationId.isEmpty
              ? Center(
                  child: Text("Start a conversation with ${widget.user.username}"),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _firestoreMethods.getMessages(widget.conversationId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }

                    List<DocumentSnapshot> docs = snapshot.data!.docs;
                    List<dynamic> itemsWithSeparators = _processMessagesForDateSeparators(docs);
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
      return _buildMessageTile(messageData, isMe);
    } else if (item is DateTime) {
      return _buildDateSeparator(item);
    } else {
      return SizedBox.shrink(); // This should not happen
    }
  }

  Widget _buildDateSeparator(DateTime date) {
    // Format the date as needed. Here's an example:
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
        decoration: BoxDecoration(
          color: isMe ? highlightColor : darkLBackgroundColor,
          borderRadius: isMe
              ? const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                )
              : const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
        ),
        child: Text(
          messageData['content'] ?? "Message not available",
          style: TextStyle(color: isMe ? primaryColor : primaryColor),
        ),
      ),
    );
  }

  Expanded _buildMessagesList(List<dynamic> items) {
    return Expanded(
      child: ListView.builder(
        controller: _scrollController, // Use the ScrollController here
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildItem(items[index]);
        },
      ),
    );
  }

  Widget _buildImageMessage() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          // Your image widget will go here
          width: 200,
          height: 200,
          decoration: BoxDecoration(
              // Add image decoration properties
              ),
          child: Image.network(
            'YourImageURLHere',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentTile(String documentName) {
    return ListTile(
      leading: Icon(Icons.picture_as_pdf),
      title: Text(documentName),
      onTap: () {
        // Handle document opening
      },
    );
  }

  Widget _buildInputArea() {
    return Row(
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
            decoration: InputDecoration(hintText: 'Message...'),
          ),
        ),
        IconButton(
          icon: Icon(Icons.send),
          onPressed:
              sendMessage, // Call the sendMessage method when the send button is pressed
        ),
      ],
    );
  }
}
