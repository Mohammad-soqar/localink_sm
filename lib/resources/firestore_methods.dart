import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:localink_sm/models/ARitem.dart';
import 'package:localink_sm/models/UserContentInteraction.dart';
import 'package:localink_sm/models/post.dart';
import 'package:localink_sm/models/post_interaction.dart';
import 'package:localink_sm/resources/auth_methods.dart';
import 'package:localink_sm/resources/storage_methods.dart';
import 'package:localink_sm/screens/login_screen.dart';
import 'package:localink_sm/utils/location_utils.dart';
import 'package:uuid/uuid.dart';

class FireStoreMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  RegExp regex = RegExp(r'\B#\w+');
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final StorageMethods _storageMethods = StorageMethods();

  //upload post

  Future<String> createPost(
    String uid,
    String caption,
    String postTypeName,
    File mediaFile,
    double latitude,
    double longitude,
  ) async {
    try {
      String res = "Some error occurred";
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
      });
      String postId = newPostRef.id;

      await newPostRef.update({
        'id': postId,
      });
      await _createPostMedia(newPostRef.id, newPostRef, mediaFile);
      return ('success');
    } catch (e) {
      return ('Error creating post: $e');
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
      await postRef.collection('postMedia').add({
        'postId': postId,
        'mediaUrl': mediaUrl,
      });
    } catch (e) {
      print('Error creating post media: $e');
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

  Future<String> likePost(
    String userId,
    String postId,
    String postCreatorId,
    List<String>? contentTypes,
  ) async {
    String res = "Some error occurred";
    try {
      CollectionReference reactionsCollection =
          _firestore.collection('posts').doc(postId).collection('reactions');

      DocumentSnapshot reactionDoc =
          await reactionsCollection.doc(userId).get();

      if (reactionDoc.exists) {
        await reactionsCollection.doc(userId).delete();
        res = "unliked";
        await _addLikeToHistory(userId, postId, postCreatorId, res);
      } else {
        Reaction reaction = Reaction(id: userId, postId: postId, uid: userId);
        await reactionsCollection.doc(userId).set(reaction.toJson());
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
    String res = "Some error occurred";

    try {
      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      print(e.toString());
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

  Future<String> uploadARItem(String name, String description,
      GeoPoint location, Uint8List modelFile, ItemType type) async {
    String res = "Some error occurred";
    try {
      String modelUrl =
          await StorageMethods().uploadARImageToStorage('arItems', modelFile);

      String itemId = const Uuid().v1();

      ARItem arItem = ARItem(
        id: itemId,
        name: name,
        description: description,
        location: location,
        modelUrl: modelUrl,
        type: type,
      );

      _firestore.collection('arItems').doc(itemId).set(arItem.toJson());
      res = "success";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  Future<String?> sendMessage({
    String? conversationId,
    required String senderId,
    String? messageText,
    Uint8List? mediaBytes,
    String? sharedPostId, // New parameter for shared post ID

    required String messageType,
    List<String>? participantIDs,
  }) async {
    String content;
    if (messageType == 'text' && messageText != null) {
      content = messageText;
    } else if (mediaBytes != null) {
      String mediaUrl = await StorageMethods().uploadImageToStorage(
          'message_media/$conversationId', mediaBytes, false);
      content = mediaUrl;
    } else if (messageType == 'post' && sharedPostId != null) {
      content =
          sharedPostId; // Here you could just use the post ID to identify the shared post
    } else {
      throw 'No content to send';
    }

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
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'type': messageType,
       if (messageType == 'post') 'sharedPostId': sharedPostId,
    };

    await _firestore
        .collection('conversations/$conversationId/messages')
        .add(message);

    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage':
          messageType == 'text' ? content : '[${messageType.toUpperCase()}]',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });

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

  Stream<QuerySnapshot> getMessages(String conversationId) {
    return _firestore
        .collection('conversations/$conversationId/messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> resetUnreadCount(String conversationId, String userId) async {
    try {
      String fieldPath = 'unreadCounts.$userId';

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .update({
        fieldPath: 0,
      });
    } catch (e) {
      print('Error resetting unread count: $e');
    }
  }

  Future<String> createConversation(List<String> participantIDs) async {
    participantIDs.sort();
    String participantsKey = participantIDs.join('_');

    DocumentReference conversation =
        await _firestore.collection('conversations').add({
      'participantIDs': participantIDs,
      'participantsKey': participantsKey,
    });

    return conversation.id;
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
}
