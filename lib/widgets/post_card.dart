// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class PostCard extends StatefulWidget {
  final snap;

  const PostCard({Key? key, required this.snap}) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with AutomaticKeepAliveClientMixin {
  late Future<List<String>> _mediaUrlsFuture;
  int commentLen = 0;
  bool isLikeAnimating = false;
  bool _isLoading = false;
  int likesCount = 0;
  model.User? userData;
  List<String> reactions = [];
  VideoPlayerController? _videoPlayerController;
  bool _isMuted = true;
  late Stream<List<String>> followingListStream;
  final TextEditingController _messageController = TextEditingController();
  final FireStoreMethods _firestoreMethods = FireStoreMethods();
  bool isPostedByVisitor = false;
  String? _postType;
  String? postId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchPostType();
    fetchUserData();
    followingListStream = _getUserFollowingList();
    likesCount = widget.snap['likesCount'] ?? 0;

    postId = widget.snap['id'];
    if (widget.snap['mediaType'] == 'video') {
      _videoPlayerController =
          VideoPlayerController.networkUrl(widget.snap['mediaUrl'])
            ..initialize().then((_) {
              setState(() {});
              _videoPlayerController!.setVolume(_isMuted ? 0 : 1);
            });
    }
    if (postId != null) {
      fetchReactions(postId!);
    }
    fetchCommentLen();

    _mediaUrlsFuture = fetchPostMediaUrls(widget.snap);
  }

  void _fetchPostType() async {
    DocumentReference postTypeRef = widget.snap['postType'];
    DocumentSnapshot postTypeSnapshot = await postTypeRef.get();
    if (mounted) {
      setState(() {
        _postType = postTypeSnapshot[
            'postType_name']; // Correct field name as per your database
      });
    }
  }

  fetchUserData() async {
    try {
      dynamic uid = widget.snap['uid'];
      DocumentSnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      userData = model.User.fromSnap(userSnapshot);
      if (mounted) {
        setState(() {});
      }
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

      bool isVisiting = postMap['isVisitor'];

      isPostedByVisitor = isVisiting;

   

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
      if (mounted) {
        setState(() {});
      }
    } catch (err) {
      print('Error fetching comment length: $err');
    }
  }

  Future<void> fetchReactions(String postId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> reactionSnapshot =
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .collection('reactions')
              .get();

      List<String> fetchedReactions =
          reactionSnapshot.docs.map((doc) => doc.id).toList();

      if (mounted) {
        setState(() {
          reactions = fetchedReactions;
        });
      }
    } catch (error) {
      print("Error fetching reactions: $error");
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
            style: const TextStyle(
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
          style: const TextStyle(
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

/*   void _initializeVideoPlayer(String mediaUrl) {
    Uri mediaUri = Uri.parse(mediaUrl);
    _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.networkUrl(mediaUri);

    _videoPlayerController!.initialize().then((_) {
      if (mounted) {
        setState(() {});
      }
    }).catchError((error) {
      print("Error initializing VideoPlayerController: $error");
    });
  } */

  Widget _buildImage(String mediaUrl) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.45, // Size from MediaQuery
      width: double.infinity,
      decoration: BoxDecoration(
        color: darkBackgroundColor, // Placeholder color
        image: mediaUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(mediaUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
    );
  }

/*   Widget _buildVideoPlayer(String mediaUrl) {
    double videoHeight =
        MediaQuery.of(context).size.height * 0.45; // Derived video height

    // Ensure the controller is only initialized once or when the URL changes
    if (_videoPlayerController == null ||
        _videoPlayerController!.dataSource != mediaUrl) {
      _videoPlayerController?.dispose();
      _videoPlayerController = VideoPlayerController.network(mediaUrl)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoPlayerController!.play();
          }
        }).catchError((error) {
          print("Error initializing VideoPlayerController: $error");
        });
    }

    return AspectRatio(
      aspectRatio: _videoPlayerController?.value.isInitialized ?? false
          ? _videoPlayerController!.value.aspectRatio
          : MediaQuery.of(context).size.width / videoHeight,
      child: _videoPlayerController?.value.isInitialized ?? false
          ? VideoPlayer(_videoPlayerController!)
          : Container(
              height: videoHeight,
              width: MediaQuery.of(context).size.width,
              color: Colors.black, // Placeholder color
            ),
    );
  } */

  Stream<List<String>> _getUserFollowingList() async* {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    var userSnap =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    var followingList = userSnap.data()!['following'];
    yield List<String>.from(followingList);
  }

  Stream<List<model.User>> _getUserProfiles(List<String> userIds) async* {
    List<model.User> profiles = [];

    for (String userId in userIds) {
      var userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      profiles.add(model.User.fromSnap(userSnap));
    }

    yield profiles;
  }

  void _onShareButtonPressed() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        // State to track the selected user
        String? selectedUserId;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: Container());
            }
            if (!userSnapshot.hasData || userSnapshot.data!.data() == null) {
              return Center(child: Text("No following information available."));
            }
            List<String> followingUserIds =
                List<String>.from(userSnapshot.data!.get('following'));

            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Container(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Share with...',
                          style: TextStyle(
                              fontSize: 18.0, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: followingUserIds.length,
                          itemBuilder: (BuildContext context, int index) {
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(followingUserIds[index])
                                  .get(),
                              builder: (context, followingSnapshot) {
                                if (followingSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(child: Container());
                                }
                                if (!followingSnapshot.hasData ||
                                    followingSnapshot.data!.data() == null) {
                                  return Container();
                                }
                                var followingUserData = followingSnapshot.data!
                                    .data() as Map<String, dynamic>;

                                bool isSelected =
                                    followingUserIds[index] == selectedUserId;

                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      selectedUserId = isSelected
                                          ? null
                                          : followingUserIds[
                                              index]; // Toggle selection
                                    });
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        margin:
                                            EdgeInsets.symmetric(horizontal: 4),
                                        padding: EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isSelected
                                                ? highlightColor
                                                : Colors
                                                    .transparent, // Highlight border if selected
                                            width: 2,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: CircleAvatar(
                                          backgroundImage: NetworkImage(
                                              followingUserData['photoUrl']),
                                          radius: 30,
                                        ),
                                      ),
                                      Text(
                                        followingUserData[
                                            'username'], // Username text
                                        style: const TextStyle(
                                          color:
                                              primaryColor, // Set the color that fits your design
                                          fontSize:
                                              14, // Adjust the size accordingly
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      if (selectedUserId !=
                          null) // Send button shows if a user is selected
                        ElevatedButton(
                          child: const Text('Send'),
                          onPressed: () {
                            sendPostMessage(selectedUserId!, postId!);
                            Navigator.of(context).pop();
                          },
                        ),
                     
                      // Add more items here
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void sendPostMessage(String userId, String postId) async {
    try {
      String receiverUserId = userId;
      String? existingConversationId;

      await _firestoreMethods.sendMessage(
        conversationId: existingConversationId,
        participantIDs: [
          FirebaseAuth.instance.currentUser!.uid,
          receiverUserId
        ],
        senderId: FirebaseAuth.instance.currentUser!.uid,
        messageText: _messageController.text.trim(),
        messageType: 'post',
        sharedPostId: postId,
      );
      _messageController.clear();
    } catch (e) {
      print(e);
    }
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
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        margin: const EdgeInsets.symmetric(vertical: 2.0),
        decoration: const BoxDecoration(
          color: darkBackgroundColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        title: Row(
                          children: [
                            Text(userData!.username),
                            const SizedBox(width: 4),
                            if(isPostedByVisitor)
                            _buildBadge(),
                            
                          ],
                        ),
                        subtitle: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/locamap.svg',
                                  height: 13,
                                  color: highlightColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.snap['locationName'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
              ),

            // Post picture
            FutureBuilder(
              future: _mediaUrlsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(); // No loading indicator
                } else if (snapshot.hasError) {
                  return const Text('Error fetching post media');
                } else if (_postType == null) {
                  return Container(); // No loading indicator while fetching post type
                } else {
                  List<String> mediaUrls = snapshot.data as List<String>;
                  return Column(
                    children: mediaUrls.map((mediaUrl) {
                      return _postType == 'videos'
                          ? Container() /* _buildVideoPlayer(mediaUrl) */
                          : _buildImage(mediaUrl);
                    }).toList(),
                  );
                }
              },
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: LikeAnimation(
                    isAnimating: reactions.contains(user?.uid),
                    smallLike: true,
                    child: GestureDetector(
                      onTap: () async {
                        setState(() {
                          isLikeAnimating = true;
                        });

                        await FireStoreMethods().likePost(
                          user!.uid,
                          widget.snap['id'],
                          widget.snap['uid'],
                          widget.snap['hashtags'].cast<String>(),
                        );

                        await fetchReactions(widget.snap['id']);

                        // Update likes count in the UI
                        DocumentSnapshot postDoc = await FirebaseFirestore
                            .instance
                            .collection('posts')
                            .doc(widget.snap['id'])
                            .get();
                        setState(() {
                          likesCount = postDoc['likesCount'] ?? 0;
                          isLikeAnimating = false;
                        });
                      },
                      child: reactions.contains(user?.uid)
                          ? SvgPicture.asset(
                              'assets/icons/like.svg',
                              height: 24,
                              color: highlightColor,
                            )
                          : SvgPicture.asset(
                              'assets/icons/like.svg',
                              height: 24,
                              color: Colors.white,
                            ),
                    ),
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
                  onPressed: _onShareButtonPressed, // Updated this line
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
                    onPressed: () async {
                      await FireStoreMethods().savePost(
                        user!.uid,
                        widget.snap['id'],
                        widget.snap['uid'],
                        widget.snap['caption'],
                        widget.snap['hashtags'].cast<String>(),
                      );
                    },
                  ),
                ))
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 0),
              child: Text(
                '$likesCount likes',
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
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

  Widget _buildBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlightColor2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Visitor',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
