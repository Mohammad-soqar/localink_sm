import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/models/post_interaction.dart';
import 'package:localink_sm/models/report.dart';
import 'package:localink_sm/resources/storage_methods.dart';
import 'package:localink_sm/utils/location_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class FireStoreMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  RegExp regex = RegExp(r'\B#\w+');
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<String> createPost(
    String uid,
    String caption,
    String postTypeName,
    File mediaFile,
    double latitude,
    double longitude,
    bool isVisitor,
    String privacy, // New parameter
    DateTime? scheduledDate, // New parameter
    //List<String> tags // New parameter
  ) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      DocumentReference postTypeRef =
          await _getPostTypeReferenceByName(postTypeName);

      CollectionReference posts = firestore.collection('posts');

      Map<String, dynamic> postData = {
        'uid': uid,
        'caption': caption,
        'createdDatetime': scheduledDate ?? FieldValue.serverTimestamp(),
        'postType': postTypeRef,
        'longitude': longitude,
        'latitude': latitude,
        'locationName':
            await LocationUtils.getAddressFromLatLng(latitude, longitude),
        'hashtags':
            regex.allMatches(caption).map((match) => match.group(0)!).toList(),
        'isVisitor': isVisitor,
        'privacy': privacy, // New field
        //'tags': tags, // New field
      };

      DocumentReference newPostRef = await posts.add(postData);
      String postId = newPostRef.id;

      await newPostRef.update({
        'id': postId,
      });
      await _createPostMedia(newPostRef.id, newPostRef, mediaFile);
      return 'success';
    } catch (e) {
      return 'Error creating post: $e';
    }
  }

  Future<void> _createPostMedia(
    String postId,
    DocumentReference postRef,
    File mediaFile,
  ) async {
    try {
      String mediaUrl =
          await StorageMethods().uploadMediaToStorage(postId, mediaFile);

      // Update Firestore with the temporary URL
      await postRef.collection('postMedia').add({
        'postId': postId,
        'mediaUrl': mediaUrl,
      });

      // The Firebase Function will handle updating Firestore with the transcoded URL
    } catch (e) {
      print('Error creating post media: $e');
    }
  }

  Future<String> createTextPost(
    String uid,
    String caption,
    String postTypeName,
    double latitude,
    double longitude,
    bool isVisitor,
  ) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      DocumentReference postTypeRef =
          await _getPostTypeReferenceByName(postTypeName);

      CollectionReference posts = firestore.collection('posts');

      DocumentReference newPostRef = await posts.add({
        'uid': uid,
        'caption': caption,
        'createdDatetime': FieldValue.serverTimestamp(),
        'postType': postTypeRef,
        'longitude': longitude,
        'latitude': latitude,
        'locationName': await LocationUtils.getAddressFromLatLng(
          latitude,
          longitude,
        ),
        'hashtags':
            regex.allMatches(caption).map((match) => match.group(0)!).toList(),
        'isVisitor': isVisitor,
      });
      String postId = newPostRef.id;

      await newPostRef.update({
        'id': postId,
      });

      // No call to _createPostMedia as it's a text-based post

      return 'success';
    } catch (e) {
      return 'Error creating text post: $e';
    }
  }

  Future<DocumentReference> _getPostTypeReferenceByName(
      String postTypeName) async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('postTypes')
          .where('postType_name', isEqualTo: postTypeName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.reference;
      }
    } catch (e) {
      print('Error fetching post type reference: $e');
    }
    return FirebaseFirestore.instance.collection('postTypes').doc();
  }

  Future<String> savePost(
    String userId,
    String postId,
    String postCreatorId,
    String caption,
    List<String>? hashtags,
  ) async {
    String res = "Some error occurred";
    try {
      CollectionReference savedCollection =
          _firestore.collection('posts').doc(postId).collection('saved');

      DocumentSnapshot savedDoc = await savedCollection.doc(userId).get();

      if (savedDoc.exists) {
        await savedCollection.doc(userId).delete();
        res = "unsaved";
        await _addPostToSaved(
            userId, postId, postCreatorId, caption, hashtags, res);
      } else {
        Reaction reaction = Reaction(id: userId, postId: postId, uid: userId);
        await savedCollection.doc(userId).set(reaction.toJson());
        res = "saved";
        await _addPostToSaved(
            userId, postId, postCreatorId, caption, hashtags, res);
      }
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  Future<void> _addPostToSaved(
    String userId,
    String postId,
    String postCreatorId,
    String caption,
    List<String>? hashtags,
    String action, // 'liked' or 'unliked'
  ) async {
    // Reference to an anchor document inside the 'interactions' subcollection of the user document
    DocumentReference interactionDocRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('interactions')
        .doc(
            'Interaction_data'); // This 'data' doc acts as an anchor for the 'saved' and 'comments' subcollections

    // Direct reference to the 'saved' subcollection under the anchor document
    CollectionReference likesCollection = interactionDocRef.collection('saved');

    if (action == "saved") {
      try {
        // Prepare the save data
        Map<String, dynamic> savedData = {
          'userId': userId,
          'postId': postId,
          'postCreatorId': postCreatorId,
          'caption': caption,
          'hashtags': hashtags ?? [], //what to write here?,
          'timestamp': FieldValue.serverTimestamp(),
        };

        // Add the saved post data to the 'saved' subcollection
        await likesCollection.add(savedData);
      } catch (e) {
        print("Error adding like to user's interactions: $e");
      }
    } else if (action == "unsaved") {
      try {
        // Find and remove the saved post from the 'saved' subcollection
        QuerySnapshot query =
            await likesCollection.where('postId', isEqualTo: postId).get();
        for (var doc in query.docs) {
          await likesCollection.doc(doc.id).delete();
        }
      } catch (e) {
        print("Error removing like from user's interactions: $e");
      }
    }
  }

  Future<String> likePost(
    String userId,
    String postId,
    String postCreatorId,
    List<String>? contentTypes,
  ) 
  
  
  async {
    String res = "Some error occurred";
    try {
      CollectionReference reactionsCollection =
          _firestore.collection('posts').doc(postId).collection('reactions');

      DocumentSnapshot reactionDoc =
          await reactionsCollection.doc(userId).get();

      DocumentReference postRef = _firestore.collection('posts').doc(postId);

      if (reactionDoc.exists) {
        await reactionsCollection.doc(userId).delete();
        await postRef.update({'likesCount': FieldValue.increment(-1)});
        res = "unliked";
        await _addLikeToHistory(userId, postId, postCreatorId, res);
      } else {
        Reaction reaction = Reaction(id: userId, postId: postId, uid: userId);
        await reactionsCollection.doc(userId).set(reaction.toJson());
        await postRef.update({'likesCount': FieldValue.increment(1)});
        res = "liked";
        await _addLikeToHistory(userId, postId, postCreatorId, res);
      }
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  Future<void> _addLikeToHistory(
    String userId,
    String postId,
    String postCreatorId,
    String action, // 'liked' or 'unliked'
  ) async {
    // Reference to an anchor document inside the 'interactions' subcollection of the user document
    DocumentReference interactionDocRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('interactions')
        .doc(
            'Interaction_data'); // This 'data' doc acts as an anchor for the 'likes' and 'comments' subcollections

    // Direct reference to the 'likes' subcollection under the anchor document
    CollectionReference likesCollection = interactionDocRef.collection('likes');

    if (action == "liked") {
      try {
        // Prepare the like data
        Map<String, dynamic> likeData = {
          'userId': userId,
          'postId': postId,
          'postCreatorId': postCreatorId,
          'likedAt': FieldValue.serverTimestamp(),
        };

        // Add the like data to the 'likes' subcollection
        await likesCollection.add(likeData);
      } catch (e) {
        print("Error adding like to user's interactions: $e");
      }
    } else if (action == "unliked") {
      try {
        // Find and remove the like from the 'likes' subcollection
        QuerySnapshot query =
            await likesCollection.where('postId', isEqualTo: postId).get();
        for (var doc in query.docs) {
          await likesCollection.doc(doc.id).delete();
        }
      } catch (e) {
        print("Error removing like from user's interactions: $e");
      }
    }
  }

  Future<String> postComment(String postId, String text, String uid,
      String name, String profilePic) async {
    String res = "Some error occurred";

    try {
      if (text.isNotEmpty) {
        String commentId = const Uuid().v1();
        _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(commentId)
            .set({
          'profilePic': profilePic,
          'name': name,
          'uid': uid,
          'text': text,
          'commentId': commentId,
          'datePublished': DateTime.now(),
        });
        res = 'success';
      } else {
        res = "Please enter text";
      }
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  Future<void> deletePost(String postId) async {
    try {
      // If this works, the issue might be with listAll or the path structure.
      // Step 1: Delete associated media from Firebase Storage
      await _storage.ref('post_media/$postId').delete();

      // Step 2: Delete subcollections (e.g., comments, postMedia)
      // Note: As Firestore does not support deleting subcollections directly,
      // you have to manually delete each document in the subcollections.
      await deleteSubcollection('posts/$postId/comments');
      await deleteSubcollection('posts/$postId/postMedia');
      await deleteSubcollection('posts/$postId/reactions');

      // Step 3: Finally, delete the post document itself
      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> deleteSubcollection(String path) async {
    final CollectionReference collectionRef = _firestore.collection(path);
    const int batchSize = 10;

    while (true) {
      final QuerySnapshot snapshot = await collectionRef.limit(batchSize).get();
      final List<DocumentSnapshot> docs = snapshot.docs;

      if (docs.isEmpty) {
        // If the subcollection is empty or doesn't exist, break the loop early.
        break;
      }

      for (var doc in docs) {
        await doc.reference.delete();
      }

      if (docs.length < batchSize) {
        // If the last batch has less documents than the batchSize, it means we've reached the end.
        break;
      }
    }
  }

  Future<void> followUser(String uid, String followId) async {
    try {
      DocumentSnapshot snap =
          await _firestore.collection('users').doc(uid).get();
      List following = (snap.data()! as dynamic)['following'];

      if (following.contains(followId)) {
        await _firestore.collection('users').doc(followId).update({
          'followers': FieldValue.arrayRemove([uid])
        });

        await _firestore.collection('users').doc(uid).update({
          'following': FieldValue.arrayRemove([followId])
        });
      } else {
        await _firestore.collection('users').doc(followId).update({
          'followers': FieldValue.arrayUnion([uid])
        });

        await _firestore.collection('users').doc(uid).update({
          'following': FieldValue.arrayUnion([followId])
        });
      }
    } catch (e) {
      if (kDebugMode) print(e.toString());
    }
  }

  Future<String?> sendMessage({
    String? conversationId,
    required String senderId,
    String? messageText,
    Uint8List? mediaBytes,
    String? sharedPostId,
    required String messageType,
    List<String>? participantIDs,
  }) async {
    final key = encrypt.Key.fromUtf8(
        'my32lengthsupersecretnooneknows1'); // 32 chars encryption key
    final iv = encrypt.IV.fromLength(16); // Random initialization vector (IV)
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    String content;

    // Encrypt text message content
    if (messageType == 'text' && messageText != null) {
      final encryptedMessage = encrypter.encrypt(messageText, iv: iv);
      content = '${iv.base64}:${encryptedMessage.base64}'; // Prepend IV
    } else if (mediaBytes != null) {
      // Upload media if provided
      String mediaUrl = await StorageMethods().uploadImageToStorage(
          'message_media/$conversationId', mediaBytes, false);
      content = mediaUrl;
    } else if (messageType == 'post' && sharedPostId != null) {
      content = sharedPostId; // For shared post, use the post ID
    } else {
      throw 'No content to send';
    }

    // If conversation does not exist, create a new one
    if (conversationId == null) {
      if (participantIDs == null || participantIDs.isEmpty) {
        throw 'Participant IDs must be provided to create a new conversation';
      }
      Map<String, dynamic> conversationDetails =
          await getOrCreateConversation(participantIDs);
      conversationId = conversationDetails['conversationId'] as String?;
    }

    var message = {
      'senderID': senderId,
      'content': content, // Encrypted content
      'timestamp': FieldValue.serverTimestamp(),
      'type': messageType,
      if (messageType == 'post') 'sharedPostId': sharedPostId,
    };

    // Store message in Firestore
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(message);

    // Update conversation details with the last message
    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': messageType == 'text'
          ? '[ENCRYPTED]'
          : '[${messageType.toUpperCase()}]',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });

    // Update unread counts for participants
    if (participantIDs != null) {
      DocumentSnapshot conversationSnapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      Map<String, dynamic> conversationData =
          conversationSnapshot.data() as Map<String, dynamic>;
      Map<String, int> unreadCounts =
          conversationData['unreadCounts']?.cast<String, int>() ?? {};
      for (String participantId in participantIDs) {
        if (participantId != senderId) {
          int currentCount = unreadCounts[participantId] ?? 0;
          unreadCounts[participantId] = currentCount + 1;
        }
      }
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({'unreadCounts': unreadCounts});
    }

    return conversationId;
  }

  encrypt.Encrypter getEncrypter() {
    final key = encrypt.Key.fromUtf8(
        'my32lengthsupersecretnooneknows1'); // 32 chars key
    return encrypt.Encrypter(encrypt.AES(key)); // Use AES encryption
  }

  String decryptMessage(String encryptedMessageWithIV) {
    final encrypter = getEncrypter();

    try {
      final parts = encryptedMessageWithIV.split(':');
      if (parts.length != 2) {
        throw 'Invalid encrypted message format';
      }

      final iv = encrypt.IV.fromBase64(parts[0]); // Extract IV
      final encryptedMessage = parts[1]; // Extract encrypted message

      return encrypter.decrypt64(encryptedMessage, iv: iv);
    } catch (e) {
      print('Decryption failed: $e');
      return encryptedMessageWithIV; // Return original message if decryption fails
    }
  }

  Stream<List<Map<String, dynamic>>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations/$conversationId/messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var messageData = doc.data() as Map<String, dynamic>;

        // Decrypt content if message type is 'text'
        if (messageData['type'] == 'text') {
          messageData['content'] = decryptMessage(messageData['content']);
        }

        return messageData;
      }).toList();
    });
  }

  Future<String> createConversation(List<String> participantIDs) async {
    participantIDs.sort();
    String participantsKey = participantIDs.join('_');

    DocumentReference conversation =
        await _firestore.collection('conversations').add({
      'participantIDs': participantIDs,
      'participantsKey': participantsKey,
      'lastMessage': '',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'unreadCounts': {for (var id in participantIDs) id: 0},
    });

    return conversation.id;
  }

  Future<void> resetUnreadCount(String conversationId, String userId) async {
    try {
      DocumentSnapshot conversationSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationSnapshot.exists) {
        String fieldPath = 'unreadCounts.$userId';
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .update({
          fieldPath: 0,
        });
      } else {
        print('Conversation does not exist, cannot reset unread count.');
      }
    } catch (e) {
      print('Error resetting unread count: $e');
    }
  }

  Future<void> updateUserLastActive(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> getOrCreateConversation(
      List<String> participantIDs) async {
    participantIDs.sort();
    String participantsKey = participantIDs.join('_');

    final QuerySnapshot conversationSnapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .where('participantsKey', isEqualTo: participantsKey)
        .limit(1)
        .get();

    if (conversationSnapshot.docs.isEmpty) {
      createConversation(participantIDs);

      return {'conversationId': '', 'lastMessage': 'Start a conversation!!'};
    } else {
      final doc = conversationSnapshot.docs.first;
      return {
        'conversationId': doc.id,
        'lastMessage': doc['lastMessage'] ?? 'No messages yet',
        'unreadCounts': doc['unreadCounts'] ?? 'No new messages'
      };
    }
  }

  Future<String> createReport(String userId, String name,
      Uint8List referencePhoto, String description) async {
    String res = "Some error occurred";
    try {
      // Assuming you have a method to upload images and return the URL
      String photoUrl = await StorageMethods()
          .uploadImageToStorage('reportPhotos', referencePhoto, false);

      String reportId = const Uuid().v1(); // Unique ID for the report

      Report report = Report(
        userId: userId,
        name: name,
        referencePhoto: photoUrl, // URL returned after uploading the photo
        description: description,
      );

      FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .set(report.toJson());
      res = "Success";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }
  //gf
}
