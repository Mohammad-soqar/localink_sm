/* import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:localink_sm/models/post_media.dart';
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

class VideoCard extends StatefulWidget {
  final Map<String, dynamic> snap;
  final VideoPlayerController? controller; // Accept controller from outside
  final String thumbnailUrl; // Add this to accept a thumbnail URL

  const VideoCard({Key? key, required this.snap, this.controller, required this.thumbnailUrl})
      : super(key: key);

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  late Future<List<String>> _mediaUrlsFuture; // Future for post media URLs
  int commentLen = 0;
  bool isLikeAnimating = false;
  model.User? userData;
  List<String> reactions = [];
  late VideoPlayerController _videoPlayerController =
      VideoPlayerController.network('');
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

  @override
  void didUpdateWidget(VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _videoPlayerController = widget.controller ??
          VideoPlayerController.network(widget.snap['mediaUrl']);
      if (widget.controller == null) {
        _videoPlayerController.initialize().then((_) => setState(() {}));
      }
    }
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
                AspectRatio(
                  aspectRatio: _videoPlayerController.value.isInitialized
                      ? _videoPlayerController.value.aspectRatio
                      : 16 / 9,
                  child: VideoPlayer(_videoPlayerController),
                ),
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
      String receiverUserId =
          userId; // Placeholder, replace with the actual receiver's user ID
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
        padding: EdgeInsets.symmetric(vertical: 15.0),
        margin: EdgeInsets.symmetric(vertical: 2.0),
        decoration: BoxDecoration(
          color: darkBackgroundColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  return Stack(
                    children: <Widget>[
                      ...mediaUrls.map((mediaUrl) {
                        return _buildVideoPlayer(mediaUrl);
                      }).toList(),
                      _buildBottomGradient(),
                      _buildRightSideInteractionButtons(),
                      _buildBottomVideoInfo()
                    ],
                  );
                }
              },
            ),

            // Display comment length
          ],
        ),
      ),
    );
  }

  Widget _buildBottomGradient() {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 200.0, // Adjust the height as needed
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightSideInteractionButtons() {
    return Positioned(
      right: 10,
      bottom: 100,
      child: Column(
        children: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/like.svg',
              color: Colors.white,
              height: 28,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/comment.svg',
              color: Colors.white,
              height: 28,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/share.svg',
              color: Colors.white,
              height: 28,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildBottomVideoInfo() {
    return Positioned(
      left: 10,
      right: 10,
      bottom: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (userData != null) ...[
            CircleAvatar(
              backgroundImage: NetworkImage(userData!.photoUrl),
              radius: 15,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userData!.username,
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  // Assuming _buildTextSpans is correctly implemented
                  RichText(
                    text: TextSpan(
                      children: _buildTextSpans(widget.snap['caption']),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            const Text('Tundra Beats - Feel Good',
                style: TextStyle(color: Colors.white)),
          ],
        ],
      ),
    );
  }
}
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/utils/colors.dart';
import 'package:video_player/video_player.dart';

class VideoCard extends StatefulWidget {
  final Map<String, dynamic> snap;
  final VideoPlayerController? controller;
  final String thumbnailUrl;

  const VideoCard(
      {Key? key,
      required this.snap,
      this.controller,
      required this.thumbnailUrl})
      : super(key: key);

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  model.User? userData;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();

    if (widget.controller != null) {     

      _controller = widget.controller!;
    } else {
      _controller = VideoPlayerController.network(widget.snap['mediaUrl']);
    }

    _controller.addListener(_checkInitialization);
    _controller.initialize().then((_) async {
      await fetchUserData();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        _controller.play(); // Ensure the video plays when initialized
      }
    });
  }

  Future<void> _checkInitialization() async {
    if (_controller.value.isInitialized && !_controller.value.isPlaying) {

      _controller.play(); // Auto-play the video once it is initialized
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

  void _toggleMute() {
    setState(() {
      if (_controller.value.volume == 0) {
        _controller.setVolume(1.0);
        _isMuted = false;
      } else {
        _controller.setVolume(0);
        _isMuted = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: _toggleMute,
        child: Stack(
          children: <Widget>[
            Container(
              alignment: Alignment.center,
              child: _controller.value.isInitialized
                  ? Align(
                      alignment: Alignment
                          .bottomCenter, // Align the video to the bottom
                      child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller)))
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(widget.thumbnailUrl, fit: BoxFit.cover),
                        const CircularProgressIndicator(),
                      ],
                    ),
            ),
            _buildBottomGradient(),
            _buildRightSideInteractionButtons(),
            _buildBottomVideoInfo()
          ],
        ));
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      // Only dispose the controller if it was initialized in this widget
      _controller.dispose();
    }
    super.dispose();
  }

  Widget _buildBottomGradient() {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 200.0, // Adjust the height as needed
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightSideInteractionButtons() {
    return Positioned(
      right: 10,
      bottom: 100,
      child: Column(
        children: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/like.svg',
              color: Colors.white,
              height: 28,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/comment.svg',
              color: Colors.white,
              height: 28,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/share.svg',
              color: Colors.white,
              height: 28,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildBottomVideoInfo() {
    return Positioned(
      left: 10,
      right: 10,
      bottom: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (userData != null) ...[
            CircleAvatar(
              backgroundImage: NetworkImage(userData!.photoUrl),
              radius: 15,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userData!.username,
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  // Assuming _buildTextSpans is correctly implemented
                  RichText(
                    text: TextSpan(
                      children: _buildTextSpans(widget.snap['caption']),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            const Text('Tundra Beats - Feel Good',
                style: TextStyle(color: Colors.white)),
          ],
        ],
      ),
    );
  }
}
