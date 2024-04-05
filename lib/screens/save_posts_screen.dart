import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:localink_sm/widgets/post_card.dart';

class SavedPostsPage extends StatefulWidget {
  final String userId;

  SavedPostsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _SavedPostsPageState createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 20; // Number of documents to fetch per page
  DocumentSnapshot? _lastDocument;
  List<DocumentSnapshot> _savedPosts = [];
  bool _hasMoreSavedPosts = true;

  @override
  void initState() {
    super.initState();
    _fetchSavedPosts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
              _scrollController.position.maxScrollExtent &&
          _hasMoreSavedPosts) {
        _fetchSavedPosts();
      }
    });
  }

  Future<void> _fetchSavedPosts() async {
    if (!_hasMoreSavedPosts) return;

    Query query = _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('interactions')
        .doc('Interaction_data')
        .collection('saved')
        .orderBy('timestamp',
            descending:
                true)
        .limit(_pageSize);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    QuerySnapshot querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDocument = querySnapshot.docs.last;
      _savedPosts.addAll(querySnapshot.docs);
    }

    if (querySnapshot.docs.length < _pageSize) {
      _hasMoreSavedPosts = false;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Posts'),
      ),
      body: GridView.builder(
        controller: _scrollController,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4.0,
          mainAxisSpacing: 4.0,
        ),
        itemCount: _savedPosts.length,
        itemBuilder: (BuildContext context, int index) {
          DocumentSnapshot likeSnapshot = _savedPosts[index];
          String postId = likeSnapshot['postId'];

          // Reference to the postMedia subcollection of the current post
          CollectionReference postMediaCollection = _firestore
              .collection('posts')
              .doc(postId)
              .collection('postMedia');

          return FutureBuilder<QuerySnapshot>(
            future: postMediaCollection
                .limit(1)
                .get(), // Assuming we're only interested in the first media item
            builder: (BuildContext context,
                AsyncSnapshot<QuerySnapshot> postMediaSnapshot) {
              if (postMediaSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!postMediaSnapshot.hasData ||
                  postMediaSnapshot.data!.docs.isEmpty) {
                // If no media is associated with the post, proceed to delete the corresponding like document
                likeSnapshot.reference.delete().then((_) {
                  print(
                      'Saved post document for postId $postId deleted successfully.');
                }).catchError((error) {
                  print('Error deleting Saved post document: $error');
                });

                // Schedule a callback to remove the like from the list after the build process is complete
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _savedPosts.removeAt(index);
                    });
                  }
                });

                // You might want to return a placeholder widget until the state is updated
                return Center(child: Text('Removing Saved post...'));
              }

              String mediaUrl = postMediaSnapshot.data!.docs.first['mediaUrl'];

              return InkWell(
                onTap: () {
                  // Navigate to the Full Post Page with the postId
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
    DocumentReference postRef =
        FirebaseFirestore.instance.collection('posts').doc(postId);

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
          Map<String, dynamic> postData =
              snapshot.data!.data() as Map<String, dynamic>;
          postData['id'] = snapshot.data!.id;

          return PostCard(snap: postData);
        },
      ),
    );
  }
}
