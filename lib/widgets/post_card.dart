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

class _PostCardState extends State<PostCard> {
  late Future<List<String>> _mediaUrlsFuture; // Future for post media URLs
  int commentLen = 0;
  bool isLikeAnimating = false;
  model.User? userData;
  List<String> reactions = [];
  VideoPlayerController? _videoPlayerController;
  bool _isMuted = true;
  late Stream<List<String>> followingListStream;
  final TextEditingController _messageController = TextEditingController();
  final FireStoreMethods _firestoreMethods = FireStoreMethods();



  String? _postType;
  String? postId;

  @override
  void initState() {
    super.initState();
    _fetchPostType();
    fetchUserData();
    followingListStream = _getUserFollowingList();

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
              .collection('reactions')
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

  void _initializeVideoPlayer(String mediaUrl) {
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
  }

  Widget _buildImage(String mediaUrl) {
    return Container(
      height:
          MediaQuery.of(context).size.height * 0.45, // Adjust size as needed
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(mediaUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(String mediaUrl) {
    // Ensure the controller is only initialized once or when the URL changes
    if (_videoPlayerController == null ||
        _videoPlayerController!.dataSource != mediaUrl) {
      _videoPlayerController?.dispose();
      // ignore: deprecated_member_use
      _videoPlayerController = VideoPlayerController.network(mediaUrl)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              // Video player initialized, UI needs to be updated
            });
            _videoPlayerController!.play();
          }
        }).catchError((error) {
          print("Error initializing VideoPlayerController: $error");
        });
    }

    return AspectRatio(
      aspectRatio: _videoPlayerController?.value.isInitialized ?? false
          ? _videoPlayerController!.value.aspectRatio
          : 16 / 9,
      child: _videoPlayerController?.value.isInitialized ?? false
          ? Stack(
              alignment: Alignment.bottomRight,
              children: [
                VideoPlayer(_videoPlayerController!),
                IconButton(
                  icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _isMuted = !_isMuted;
                        _videoPlayerController!.setVolume(_isMuted ? 0 : 1);
                      });
                    }
                  },
                ),
              ],
            )
          : Center(child: CircularProgressIndicator()),
    );
  }

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
              return Center(child: CircularProgressIndicator());
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
                      Padding(
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
                                  return Center(
                                      child: CircularProgressIndicator());
                                }
                                if (!followingSnapshot.hasData ||
                                    followingSnapshot.data!.data() == null) {
                                  return Container(); // Empty container in case of no data
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
                          child: Text('Send'),
                          onPressed: () {
                            sendPostMessage(selectedUserId!, postId!);
                            Navigator.of(context).pop();
                          },
                        ),
                      Divider(),
                      ListTile(
                        leading: Icon(Icons.add_circle_outline),
                        title: Text('Add to story'),
                        onTap: () {
                          // Add to story functionality
                          Navigator.of(context).pop();
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.file_download),
                        title: Text('Download'),
                        onTap: () {
                          // Download functionality
                          Navigator.of(context).pop();
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.content_copy),
                        title: Text('Copy link'),
                        onTap: () {
                          // Copy link functionality
                          Navigator.of(context).pop();
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.message),
                        title: Text('WhatsApp'),
                        onTap: () {
                          // Share to WhatsApp functionality
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

        String receiverUserId = userId; // Placeholder, replace with the actual receiver's user ID
        String? existingConversationId; // This should be set if there's an existing conversation selected

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
          messageType: 'post', // Indicating that this is a text message
          sharedPostId: postId,
        );
        _messageController.clear();
      } catch (e) {
        print(e); // Ideally, use a more user-friendly way to show the error
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
                  return CircularProgressIndicator(); // Show loading indicator while fetching media URLs
                } else if (snapshot.hasError) {
                  return Text('Error fetching post media');
                } else if (_postType == null) {
                  return CircularProgressIndicator(); // Show loading indicator while fetching post type
                } else {
                  List<String> mediaUrls = snapshot.data as List<String>;
                  return Column(
                    children: mediaUrls.map((mediaUrl) {
                      return _postType == 'videos'
                          ? _buildVideoPlayer(mediaUrl)
                          : _buildImage(mediaUrl);
                    }).toList(),
                  );
                }
              },
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                LikeAnimation(
                  isAnimating: reactions?.contains(user?.uid) ?? false,
                  smallLike: true,
                  child: IconButton(
                    icon: reactions!.contains(user?.uid)
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
                    onPressed: () async {
                      setState(() {
                        isLikeAnimating = true;
                      });

                      await FireStoreMethods().likePost(
                        user!.uid,
                        widget.snap['id'],
                        widget.snap['uid'],
                        widget.snap['hashtags'].cast<String>(),
                      );

                      fetchReactions(widget.snap['id']);

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
