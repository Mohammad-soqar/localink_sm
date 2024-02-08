import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/models/ARitem.dart';
import 'package:localink_sm/models/UserContentInteraction.dart';
import 'package:localink_sm/models/post.dart';
import 'package:localink_sm/resources/auth_methods.dart';
import 'package:localink_sm/resources/storage_methods.dart';
import 'package:localink_sm/screens/login_screen.dart';
import 'package:uuid/uuid.dart';

class FireStoreMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String postId = const Uuid().v1();
  RegExp regex = RegExp(r'\B#\w+');
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  //upload post
  Future<String> uploadPost(
    String description,
    Uint8List file,
    String uid,
    String username,
    String profileImage,
  ) async {
    String res = "Some error occurred";
    DocumentSnapshot userSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!userSnapshot.exists) {
      
      return "User account is deleted.";
    } else {
      try {
        String photoUrl =
            await StorageMethods().uploadImageToStorage('posts', file, true);
        Post post = Post(
          description: description,
          uid: uid,
          username: username,
          profileImage: profileImage,
          postId: postId,
          datePublished: DateTime.now(),
          postUrl: photoUrl,
          likes: [],
          hashtags: regex
              .allMatches(description)
              .map((match) => match.group(0)!)
              .toList(),
        );
        print(post.hashtags);
        _firestore.collection('posts').doc(postId).set(
              post.toJson(),
            );
        res = "success";
      } catch (err) {
        res = err.toString();
      }
    }

    return res;
  }

  Future<String> likePost(
      String userId, String postId, List<String> contentTypes) async {
    String res = "Some error occurred";
    try {
      // Check if the post document exists
      var postSnapshot = await _firestore.collection('posts').doc(postId).get();
      if (postSnapshot.exists) {
        // Check if the user already likes the post
        var likes = postSnapshot.data()?['likes'] ?? [];
        bool userLiked = likes.contains(userId);

        if (userLiked) {
          // User liked the post, so unlike it
          await _firestore.collection('posts').doc(postId).update({
            'likes': FieldValue.arrayRemove([userId]),
          });

          // Remove the interaction from userContentInteractions
          var userInteractionQuery = await _firestore
              .collection('userContentInteractions')
              .doc(userId)
              .collection('Interactions')
              .where('contentId', isEqualTo: postId)
              .get();
          var interactionDocs = userInteractionQuery.docs;

          // Assuming there's at most one interaction with the same post ID (adapt if needed)
          if (interactionDocs.isNotEmpty) {
            var interactionId = interactionDocs.first.id;
            await _firestore
                .collection('userContentInteractions')
                .doc(userId)
                .collection('Interactions')
                .doc(interactionId)
                .delete();
          }

          res = 'unliked';
        } else {
          // User didn't like the post, so like it
          await _firestore.collection('posts').doc(postId).update({
            'likes': FieldValue.arrayUnion([userId]),
          });

          // Add the interaction to the user's interactions collection
          Interaction interaction = Interaction(
            contentId: postId,
            interactionType: 'like',
            contentTypes: contentTypes,
          );
          await _firestore
              .collection('userContentInteractions')
              .doc(userId)
              .collection('Interactions')
              .add(
                interaction.toJson(),
              );

          res = 'liked';
        }
      } else {
        res = 'Post not found';
      }
    } catch (err) {
      res = err.toString();
    }
    return res;
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

  //deleting post
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
}
