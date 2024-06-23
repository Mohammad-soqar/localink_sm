import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_svg/svg.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/screens/comment_screen.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/widgets/like_animation.dart';

class VideoCard extends StatefulWidget {
  final Map<String, dynamic> snap;
  final ChewieController chewieController;

  const VideoCard({
    Key? key,
    required this.snap,
    required this.chewieController,
  }) : super(key: key);

  @override
  _VideoCardState createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  late ChewieController _chewieController;
  model.User? userData;
  bool _isMuted = false;
  List<String> reactions = [];
  int likesCount = 0;

  @override
  void initState() {
    super.initState();
    _chewieController = widget.chewieController;
    _chewieController.addListener(_chewieListener);
    fetchUserData();
    fetchReactions(widget.snap['id']); // Fetch reactions for the post
  }

  void _chewieListener() {
    if (!_chewieController.videoPlayerController.value.isInitialized) return;
    setState(() {});
  }

  Future<void> fetchUserData() async {
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

      spans.add(
        TextSpan(
          text: caption.substring(startIndex, endIndex),
          style: TextStyle(
            color: highlightColor,
            fontSize: 12,
            decoration: TextDecoration.underline,
          ),
        ),
      );

      currentIndex = endIndex;
    }

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
      if (_chewieController.videoPlayerController.value.volume == 0) {
        _chewieController.setVolume(1.0);
        _isMuted = false;
      } else {
        _chewieController.setVolume(0);
        _isMuted = true;
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_chewieController.isPlaying) {
        _chewieController.pause();
      } else {
        _chewieController.play();
      }
    });
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
                           // sendPostMessage(selectedUserId!, postId!);
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        children: <Widget>[
          Container(
            alignment: Alignment.center,
            child: _chewieController.videoPlayerController.value.isInitialized
                ? Chewie(
                    controller: _chewieController,
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          _buildBottomGradient(),
          _buildRightSideInteractionButtons(),
          _buildBottomVideoInfo(),
          _buildMuteButton(), // Add mute button
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildBottomGradient() {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 200.0,
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
        LikeAnimation(
          isAnimating: reactions.contains(userData?.uid),
          smallLike: true,
          child: IconButton(
            icon: SvgPicture.asset(
              'assets/icons/like.svg',
              color: reactions.contains(userData?.uid) ? highlightColor : Colors.white,
              height: 28,
            ),
            onPressed: () async {
              await FireStoreMethods().likePost(
                userData!.uid,
                widget.snap['id'],
                userData!.uid,
                [], // Add hashtags if needed
              );

              // Fetch reactions again to update the UI
              await fetchReactions(widget.snap['id']);
            },
          ),
        ),
        IconButton(
          icon: SvgPicture.asset(
            'assets/icons/comment.svg',
            color: Colors.white,
            height: 28,
          ),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => CommentsScreen(snap: widget.snap['id']),
            );
          },
        ),
        IconButton(
          icon: SvgPicture.asset(
            'assets/icons/share.svg',
            color: Colors.white,
            height: 28,
          ),
          onPressed: _onShareButtonPressed, // Define the sharing logic
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

  Widget _buildMuteButton() {
    return Positioned(
      top: 40,
      right: 10,
      child: IconButton(
        icon: Icon(
          _isMuted ? Icons.volume_off : Icons.volume_up,
          color: Colors.white,
        ),
        onPressed: _toggleMute,
      ),
    );
  }
}
