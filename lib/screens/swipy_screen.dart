import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:video_player/video_player.dart';

class ReelsPage extends StatefulWidget {
  @override
  _ReelsPageState createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(
      'https://firebasestorage.googleapis.com/v0/b/localink-778c5.appspot.com/o/post_media%2FV1TCGKRpYCeZWDNKY4Q3?alt=media&token=b5070c3f-cc3a-4bfd-b2dd-bde8e6fdced4', // Replace with your video asset or network path
    )..initialize().then((_) {
        setState(() {}); // for updating the UI once the video is initialized
        _controller.play(); // Play the video once initialized
        _controller.setLooping(true); // Loop the video
      });
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _controller.value.isInitialized
          ? GestureDetector(
              onVerticalDragEnd: (details) {
                // TODO: Handle video swipe here
              },
              child: Stack(
                children: <Widget>[
                  VideoPlayer(_controller),
                  _buildBottomGradient(),
                  _buildRightSideInteractionButtons(),
                  _buildBottomVideoInfo(),
                ],
              ),
            )
          : Center(child: CircularProgressIndicator()),
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
            onPressed: () {
            },
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/comment.svg', 
              color: Colors.white,
              height: 28,
            ),
            onPressed: () {
            },
          ),
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/share.svg', 
              color: Colors.white,
              height: 28,
            ),
            onPressed: () {
             
            },
          ),
         
        
        ],
      ),
    );
  }

  Widget _buildBottomVideoInfo() {
    return Positioned(
      left: 10,
      right: 10,
      bottom: 40, // Distance from the bottom
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            backgroundImage: NetworkImage('https://via.placeholder.com/150'), // Replace with your network image or asset
            radius: 15,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@the.paradise.club', // Replace with dynamic data
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Video description here...', // Replace with dynamic data
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          SvgPicture.asset(
            'assets/icons/music_note.svg', // Use your own assets
            color: Colors.white,
            height: 20,
          ),
          const SizedBox(width: 5),
          const Text(
            'Tundra Beats - Feel Good', // Replace with dynamic data
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
