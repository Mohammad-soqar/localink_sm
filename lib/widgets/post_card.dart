import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:localink_sm/models/user.dart';
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/screens/comment_screen.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:provider/provider.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/providers/user_provider.dart';
import 'package:localink_sm/widgets/like_animation.dart';

class PostCard extends StatefulWidget {
  final snap;

  const PostCard({Key? key, required this.snap}) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late Future<List<String>> _mediaUrlsFuture; // Future for post media URLs
  int commentLen = 0;
  bool isLikeAnimating = false;
  model.User? userData;
  List<String> reactions = [];
  String? postId;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    postId = widget.snap['id'];
    if (postId != null) {
      // Fetch reactions when the widget is initialized
      fetchReactions(postId!);
    }
    fetchCommentLen();

    // Initialize the Future for post media URLs
    _mediaUrlsFuture = fetchPostMediaUrls(widget.snap);
  }

  fetchUserData() async {
    try {
      dynamic uid = widget.snap['uid'];
      DocumentSnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      userData = User.fromSnap(userSnapshot);
      setState(() {});
    } catch (err) {
      print('Error fetching user data: $err');
    }
  }

  Future<List<String>> fetchPostMediaUrls(Map<String, dynamic> postMap) async {
    try {
      QuerySnapshot mediaSnap = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postMap['id'])
          .collection('postMedia')
          .get();

      List<String> mediaUrls =
          mediaSnap.docs.map((doc) => doc['mediaUrl'] as String).toList();

      return mediaUrls;
    } catch (err) {
      print('Error fetching post media: $err');
      return [];
    }
  }

  fetchCommentLen() async {
    try {
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.snap['id'])
          .collection('comments')
          .get();
      commentLen = snap.docs.length;
      setState(() {});
    } catch (err) {
      print('Error fetching comment length: $err');
    }
  }

  Future<List<String>> fetchReactions(String postId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> reactionSnapshot =
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .collection('reaction')
              .get();

      List<String> reactions =
          reactionSnapshot.docs.map((doc) => doc.id).toList();
      return reactions;
    } catch (error) {
      print("Error fetching reactions: $error");
      return [];
    }
  }

  List<TextSpan> _buildTextSpans(String caption) {
    List<TextSpan> spans = [];

    RegExp regex = RegExp(r'\#\w+'); // Regex to match hashtags

    int currentIndex = 0;

    for (RegExpMatch match in regex.allMatches(caption)) {
      int startIndex = match.start;
      int endIndex = match.end;

      // Add the text before the hashtag
      if (startIndex > currentIndex) {
        spans.add(
          TextSpan(
            text: caption.substring(currentIndex, startIndex),
            style: TextStyle(
              color: primaryColor,
              fontSize: 12,
            ),
          ),
        );
      }

      // Add the hashtag with custom styling
      spans.add(
        TextSpan(
          text: caption.substring(startIndex, endIndex),
          style: TextStyle(
            color: highlightColor, // Color for hashtags
            fontSize: 12,
            decoration: TextDecoration.underline, // Underline for hashtags
          ),
        ),
      );

      currentIndex = endIndex;
    }

    // Add the remaining text if any
    if (currentIndex < caption.length) {
      spans.add(
        TextSpan(
          text: caption.substring(currentIndex),
          style: TextStyle(
            color: primaryColor,
            fontSize: 12,
          ),
        ),
      );
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final model.User? user = Provider.of<UserProvider>(context).getUser;

    return Container(
      color: darkBackgroundColor,
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 3.0),
        margin: EdgeInsets.symmetric(vertical: 2.0),
        decoration: BoxDecoration(
          color: darkBackgroundColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User information

            if (userData != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 1,
                ).copyWith(right: 0),
                child: Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(userData!.photoUrl),
                        ),
                        title: Text(userData!.username),
                        subtitle: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/icons/locamap.svg',
                              height: 13,
                              color: highlightColor,
                            ),
                            SizedBox(
                              width: 4,
                            ),
                            Text(
                              widget.snap['locationName'],
                              style: TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        showDialog(
                            context: context,
                            builder: (context) => Dialog(
                                  child: ListView(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shrinkWrap: true,
                                    children: widget.snap['uid'] == user!.uid
                                        ? ['delete']
                                            .map(
                                              (e) => InkWell(
                                                onTap: () async {
                                                  FireStoreMethods().deletePost(
                                                      widget.snap['id']);
                                                  Navigator.of(context).pop();
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    vertical: 12,
                                                    horizontal: 16,
                                                  ),
                                                  child: Text(e),
                                                ),
                                              ),
                                            )
                                            .toList()
                                        : [],
                                  ),
                                ));
                      },
                      icon: Icon(Icons.more_vert),
                    ),
                  ],
                ),
              ),

            // Post picture
            FutureBuilder(
              future: _mediaUrlsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator(); // Loading indicator
                } else if (snapshot.hasError) {
                  return Text('Error fetching post media');
                } else {
                  List<String> mediaUrls = snapshot.data as List<String>;
                  return Column(
                    children: [
                      for (var mediaUrl in mediaUrls)
                        Container(
                          height: MediaQuery.of(context).size.height * 0.45,
                          width: double.infinity,
                          child: Image.network(
                            mediaUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                    ],
                  );
                }
              },
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Like button with animation
                LikeAnimation(
                  isAnimating: reactions?.contains(user?.uid) ?? false,
                  smallLike: true,
                  child: IconButton(
                    icon: reactions!.contains(user?.uid)
                        ? SvgPicture.asset(
                            'assets/icons/like.svg',
                            height: 24,
                            color: Colors.blue,
                          )
                        : SvgPicture.asset(
                            'assets/icons/like.svg',
                            height: 24,
                            color: Colors.white,
                          ),
                    onPressed: () async {
                      // Trigger the animation by setting isLikeAnimating to true
                      setState(() {
                        isLikeAnimating = true;
                      });

                      await FireStoreMethods().likePost(
                        user!.uid,
                        widget.snap['id'],
                        widget.snap['hashtags'].cast<String>(),
                      );

                      // After liking, refresh reactions
                      fetchReactions(widget.snap['id']);

                      // After the animation is complete, set isLikeAnimating to false
                      setState(() {
                        isLikeAnimating = false;
                      });
                    },
                  ),
                ),

                // Comment button
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/comment.svg',
                    height: 24,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CommentsScreen(
                        snap: widget.snap['id'].toString(),
                      ),
                    ),
                  ),
                ),

                // Share button
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/share.svg',
                    height: 24,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    // Add share functionality
                  },
                ),

                Expanded(
                    child: Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                      icon: SvgPicture.asset(
                        'assets/icons/save.svg',
                        height: 24,
                        color: Colors.white,
                      ),
                      onPressed: () {}),
                ))
              ],
            ),

            // Like, Comment, Share buttons
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(10, 5, 15, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (userData != null)
                    Text(
                      userData!.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryColor,
                      ),
                    ),
                  SizedBox(
                    height: 8,
                  ),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                      ),
                      children: _buildTextSpans(widget.snap['caption']),
                    ),
                  ),
                ],
              ),
            ),

            // Display comment length
          ],
        ),
      ),
    );
  }
}
