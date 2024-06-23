import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:localink_sm/widgets/custom_controls.dart';
import 'package:localink_sm/widgets/video_card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({Key? key}) : super(key: key);

  @override
  _ReelsPageState createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final List<DocumentSnapshot> _posts = [];
  final Map<int, ChewieController> _chewieControllers = {};
  bool _isFetchingPosts = false;
  bool _hasMorePosts = true;
  DocumentSnapshot? _lastDocument;
  int _preloadLimit = 2;
  int _currentIndex = 0;
  List<File> _cachedVideos = [];

  @override
  void initState() {
    super.initState();
    _loadCachedVideos();
    WidgetsBinding.instance.addObserver(this);
    _fetchInitialPosts();
    _pageController.addListener(_pageListener);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.removeListener(_pageListener);
    _disposeAllControllers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pauseAllVideos();
    }
  }

  Future<void> _fetchInitialPosts() async {
    await _fetchPosts();
    if (_posts.isNotEmpty) {
      await _preloadVideoControllers(
          _currentIndex); // Preload only the current video
    }
    if (mounted) {
      setState(() {});
    }
  }
  

  Future<void> _loadCachedVideos() async {
    try {
      Directory tempDir = await getTemporaryDirectory();
      List<FileSystemEntity> files = tempDir.listSync();
      for (var file in files) {
        if (file.path.endsWith('.mp4')) {
          // Assuming videos are in .mp4 format
          _cachedVideos.add(File(file.path));
        }
      }
      // If there are cached videos, load them immediately
      if (_cachedVideos.isNotEmpty) {
        for (int i = 0; i < _cachedVideos.length; i++) {
          final videoFile = _cachedVideos[i];
          final videoPlayerController = VideoPlayerController.file(videoFile);
          await videoPlayerController.initialize();
          final chewieController = ChewieController(
            videoPlayerController: videoPlayerController,
            autoPlay: false,
            looping: true,
            showControls: false, // Hide default controls
            customControls: CustomControls(), // Use the custom controls
          );
          _chewieControllers[i] = chewieController;
        }
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Error loading cached videos: $e');
    }
  }

  void _pauseAllVideos() {
    _chewieControllers.forEach((index, controller) {
      controller.pause();
    });
  }

  void _disposeAllControllers() {
    _chewieControllers.forEach((index, controller) {
      controller.dispose();
    });
    _pauseAllVideos();
    _chewieControllers.clear();
  }

  Future<void> _fetchPosts() async {
    if (!_hasMorePosts || _isFetchingPosts) return;

    setState(() {
      _isFetchingPosts = true;
    });

    try {
      var postTypeSnapshot = await FirebaseFirestore.instance
          .collection('postTypes')
          .where('postType_name', isEqualTo: 'videos')
          .limit(1)
          .get();

      if (postTypeSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _isFetchingPosts = false;
          });
        }
        return;
      }

      DocumentReference videoTypeRef = postTypeSnapshot.docs.first.reference;

      Query query = FirebaseFirestore.instance
          .collection('posts')
          .where('postType', isEqualTo: videoTypeRef)
          .orderBy('createdDatetime', descending: true)
          .limit(5);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      QuerySnapshot querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _hasMorePosts = false;
            _isFetchingPosts = false;
          });
        }
      } else {
        _lastDocument = querySnapshot.docs.last;
        if (mounted) {
          setState(() {
            _posts.addAll(querySnapshot.docs);
            _isFetchingPosts = false;
          });
        }
        _preloadVideoControllers(_currentIndex);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingPosts = false;
        });
      }
      print('Error fetching posts: $e');
    }
  }

  void _pageListener() {
    final index = _pageController.page?.round() ?? 0;
    if (index == _posts.length - 1 && !_isFetchingPosts) {
      _fetchPosts();
    }

    if (index != _currentIndex) {
      _currentIndex = index;
      _playCurrentVideo();
      _preloadVideoControllers(_currentIndex);
      _disposeUnusedControllers(_currentIndex);
    }
  }

  Future<void> _preloadVideoControllers(int currentIndex) async {
    for (var i = currentIndex - _preloadLimit;
        i <= currentIndex + _preloadLimit;
        i++) {
      if (i < 0 || i >= _posts.length) continue;
      if (!_chewieControllers.containsKey(i)) {
        final mediaUrl = await getMediaUrl(_posts[i]);
        final videoPlayerController = VideoPlayerController.network(mediaUrl);
        await videoPlayerController.initialize();
        final chewieController = ChewieController(
          videoPlayerController: videoPlayerController,
          autoPlay: false,
          looping: true,
          showControls: false, // Hide default controls
          customControls: CustomControls(), // Use the custom controls
        );
        _chewieControllers[i] = chewieController;
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _disposeUnusedControllers(int currentIndex) {
    final disposeBefore = currentIndex - (_preloadLimit + 1);
    final disposeAfter = currentIndex + (_preloadLimit + 1);

    _chewieControllers.keys
        .where((key) => key < disposeBefore || key > disposeAfter)
        .toList()
        .forEach((key) {
      _chewieControllers[key]?.dispose();
      _chewieControllers.remove(key);
    });
  }

  Future<String> getMediaUrl(DocumentSnapshot post) async {
    if (_cachedVideos.isNotEmpty) {
      return _cachedVideos.removeAt(0).path;
    } else {
      final mediaSnap = await post.reference.collection('postMedia').get();
      if (mediaSnap.docs.isNotEmpty) {
        final mediaData = mediaSnap.docs.first.data() as Map<String, dynamic>;
        if (mediaData.containsKey('transcodedUrl')) {
          return mediaData['transcodedUrl'] as String;
        }
        return mediaData['mediaUrl'] as String;
      } else {
        throw StateError('No mediaUrl found in postMedia subcollection');
      }
    }
  }

  void _playCurrentVideo() {
    if (ModalRoute.of(context)?.isCurrent == true) {
      _chewieControllers.forEach((index, controller) {
        if (index == _currentIndex &&
            controller.videoPlayerController.value.isInitialized) {
          controller.play();
        } else {
          controller.pause();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        _pauseAllVideos();
        return true;
      },
      child: Scaffold(
        body: _buildVideoPageView(),
      ),
    );
  }

  Widget _buildVideoPageView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _posts.length,
      scrollDirection: Axis.vertical,
      onPageChanged: (index) {
        if (index == _posts.length - 1) {
          _fetchPosts();
        }
      },
      itemBuilder: (context, index) {
        final chewieController = _chewieControllers[index];

        if (chewieController == null ||
            !chewieController.videoPlayerController.value.isInitialized) {
          return Container();
        }

        return VideoCard(
          snap: _posts[index].data() as Map<String, dynamic>,
          chewieController: chewieController,
        );
      },
    );
  }
}
