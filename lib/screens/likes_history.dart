import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:localink_sm/widgets/post_card.dart';

class LikesPage extends StatefulWidget {
  final String userId;

  LikesPage({Key? key, required this.userId}) : super(key: key);

  @override
  _LikesPageState createState() => _LikesPageState();
}

class _LikesPageState extends State<LikesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    // Reference to the likes subcollection
     DocumentReference interactionDocRef = _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('interactions')
        .doc(
            'Interaction_data'); // This 'data' doc acts as an anchor for the 'likes' and 'comments' subcollections

    // Direct reference to the 'likes' subcollection under the anchor document
    CollectionReference likesCollection = interactionDocRef.collection('likes');

    return Scaffold(
      appBar: AppBar(
        title: Text('Likes'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: likesCollection.snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Text('Something went wrong');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4.0,
              mainAxisSpacing: 4.0,
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (BuildContext context, int index) {
              String postId = snapshot.data!.docs[index]['postId'];

              // Reference to the postMedia subcollection of the current post
              CollectionReference postMediaCollection =
                  _firestore.collection('posts').doc(postId).collection('postMedia');

              return FutureBuilder<QuerySnapshot>(
                future: postMediaCollection.limit(1).get(), // Assuming we're only interested in the first media item
                builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> postMediaSnapshot) {
                  if (postMediaSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!postMediaSnapshot.hasData || postMediaSnapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No media found for this post'));
                  }

                  String mediaUrl = postMediaSnapshot.data!.docs.first['mediaUrl'];

                  return InkWell(
                    onTap: () {
                      // TODO: Navigate to the Full Post Page with the postId
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullPostPage(postId: postId),
                        ),
                      );
                    },
                    child: GridTile(
                      child: Image.network(
                        mediaUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class FullPostPage extends StatelessWidget {
  final String postId;

  FullPostPage({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Reference to the post document
    DocumentReference postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Post'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: postRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('Post not found.'));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading post.'));
          }
          Map<String, dynamic> postData = snapshot.data!.data() as Map<String, dynamic>;
          postData['id'] = snapshot.data!.id; 
          
          return PostCard(snap: postData); 
        },
      ),
    );
  }
}
