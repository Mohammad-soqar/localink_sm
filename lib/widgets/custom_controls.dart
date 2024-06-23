import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

class CustomControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chewieController = ChewieController.of(context);
    return Stack(
      children: <Widget>[
        _buildProgressBar(context, chewieController),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context, ChewieController chewieController) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.0),
        color: Colors.black.withOpacity(0.5),
        child: ChewieProgressBar(chewieController),
      ),
    );
  }
}

class ChewieProgressBar extends StatelessWidget {
  const ChewieProgressBar(this.controller, {Key? key}) : super(key: key);

  final ChewieController controller;

  @override
  Widget build(BuildContext context) {
    return VideoProgressIndicator(
      controller.videoPlayerController,
      allowScrubbing: true,
      colors: VideoProgressColors(
        playedColor: Colors.red,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.white,
      ),
    );
  }
}
