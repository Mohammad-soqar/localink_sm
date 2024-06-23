import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:localink_sm/screens/profile_screen.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/widgets/post_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  bool isShowUsers = false;
  Timer? _debounce;

  @override
  void dispose() {
    super.dispose();
    searchController.dispose();
    _debounce?.cancel();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (searchController.text.isNotEmpty) {
        setState(() {
          isShowUsers = true;
        });
      } else {
        setState(() {
          isShowUsers = false;
        });
      }
    });
  }

  Future<List<DocumentSnapshot>> fetchMostLikedPosts() async {
    try {
      // Fetch top 20 most liked posts
      QuerySnapshot postSnap = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('likesCount', descending: true)
          .limit(20)
          .get();

      return postSnap.docs;
    } catch (err) {
      print('Error fetching post data: $err');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    searchController.addListener(_onSearchChanged);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkBackgroundColor,
        title: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            icon: Icon(Icons.search),
            hintText: 'Search for a user...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white54),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: isShowUsers
          ? FutureBuilder(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .get(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                var filteredDocs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  var username = data['username']?.toLowerCase() ?? '';
                  return username.contains(searchController.text.toLowerCase());
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text('No users found', style: TextStyle(color: Colors.white)),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var userDoc = filteredDocs[index];
                    var userData = userDoc.data() as Map<String, dynamic>;

                    var photoUrl = userData['photoUrl'] ?? 'https://i.stack.imgur.com/l60Hf.png';
                    var username = userData['username'] ?? 'default_username';

                    return Material(
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(
                              uid: userData['uid'],
                            ),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(photoUrl),
                            radius: 16,
                          ),
                          title: Text(username, style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    );
                  },
                );
              },
            )
          : FutureBuilder<List<DocumentSnapshot>>(
              future: fetchMostLikedPosts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                List<DocumentSnapshot> posts = snapshot.data!;

                return MasonryGridView.count(
                  crossAxisCount: 3,
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot post = posts[index];
                    List<String> mediaUrls = [];

                    return FutureBuilder(
                      future: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(post.id)
                          .collection('postMedia')
                          .get(),
                      builder: (context, mediaSnapshot) {
                        if (mediaSnapshot.hasData) {
                          mediaUrls = mediaSnapshot.data!.docs
                              .map((doc) => doc['mediaUrl'] as String)
                              .toList();
                        }

                        return mediaUrls.isNotEmpty
                            ? GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => PostCard(
                                      snap: post.data()!,
                                    ),
                                  ),
                                ),
                                child: SizedBox(
                                   height: MediaQuery.of(context).size.height * 0.15,
                                  child: Image.network(
                                    mediaUrls[0], 
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            : Container();
                      },
                    );
                  },
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                );
              },
            ),
    );
  }
}
