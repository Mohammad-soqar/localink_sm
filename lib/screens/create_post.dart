import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/providers/user_provider.dart';
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/responsive/mobile_screen_layout.dart';
import 'package:localink_sm/responsive/responsive_layout_screen.dart';
import 'package:localink_sm/responsive/web_screen_layout.dart';
import 'package:localink_sm/screens/feed_screen.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/get_coordinate.dart';
import 'package:localink_sm/utils/utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class PostPage extends StatefulWidget {
  @override
  _PostPageState createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  int _currentPage = 0; // Track the current page index
  PageController _pageController =
      PageController(initialPage: 0); // Controller for PageView

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create a Post'),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          const PhotosPage(),
          const VideosPage(),
          CreateUpdatePage(),
        ],
      ),
      bottomNavigationBar: Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildNavItem(0, 'Photos'),
              buildNavItem(1, 'Videos'),
              buildNavItem(2, 'Updates'),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildNavItem(int index, String title) {
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color:
                  _currentPage == index ? highlightColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _currentPage == index ? highlightColor : Colors.black,
          ),
        ),
      ),
    );
  }
}

class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key});

  @override
  _PhotosPageState createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  List<AssetEntity> _mediaAssets = [];
  AssetEntity? _selectedImage;
  int currentPage = 0;
  bool isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchNewMedia();
  }

  Future<void> _fetchNewMedia() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps != PermissionState.authorized && ps != PermissionState.limited) {
      setState(() => isLoading = false);
      return;
    }

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      hasAll: true,
      type: RequestType.image,
    );

    if (paths.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    final recentAlbum = paths.firstWhere((album) => album.name == "Recent",
        orElse: () => paths.first);
    final List<AssetEntity> media =
        await recentAlbum.getAssetListPaged(page: currentPage, size: 60);

    if (_selectedImage == null && media.isNotEmpty) {
      setState(() => _selectedImage = media.first);
    }

    setState(() {
      _mediaAssets.addAll(media);
      currentPage++;
      isLoading = false;
    });
  }

  void _toggleImageSelection(AssetEntity asset) {
    setState(() => _selectedImage = asset);

    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildSelectedImageWidget() {
    if (_selectedImage == null) return SizedBox.shrink();
    return FutureBuilder<File?>(
      future: _selectedImage!.file,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return Image.file(snapshot.data!, fit: BoxFit.cover);
        } else {
          return CircularProgressIndicator();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: MediaQuery.of(context).size.height * 0.48,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: _selectedImage != null
                  ? _buildSelectedImageWidget()
                  : SizedBox.shrink(),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(top: 8.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 3.0,
                  crossAxisSpacing: 3.0),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final asset = _mediaAssets[index];
                  final isSelected = _selectedImage == asset;
                  return GestureDetector(
                    onTap: () => _toggleImageSelection(asset),
                    child: GridTile(
                      key: ValueKey(
                          "${asset.id}_${isSelected ? 'selected' : 'unselected'}"),
                      child: FutureBuilder<Uint8List?>(
                        future: asset.thumbnailDataWithSize(
                            const ThumbnailSize(200, 200)),
                        builder: (BuildContext context,
                            AsyncSnapshot<Uint8List?> snapshot) {
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: snapshot.hasData
                                    ? Image.memory(snapshot.data!,
                                        fit: BoxFit.cover)
                                    : Container(color: Colors.grey[200]),
                              ),
                              if (isSelected)
                                const Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.check_circle,
                                        color: highlightColor),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
                childCount: _mediaAssets.length,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_selectedImage != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CaptionPage(
                  selectedMedia:
                      _selectedImage, // Assuming _selectedImage is an AssetEntity
                  mediaType: MediaType.photo,
                ),
              ),
            );
          }
        },
        label: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Next',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.navigate_next,
              color: Colors.white,
            ),
          ],
        ),
        backgroundColor: highlightColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }
}

enum MediaType { photo, video }

class CaptionPage extends StatefulWidget {
  final AssetEntity? selectedMedia;
  final MediaType mediaType;

  const CaptionPage({
    Key? key,
    required this.selectedMedia,
    required this.mediaType,
  }) : super(key: key);

  @override
  State<CaptionPage> createState() => _CaptionPageState();
}

class _CaptionPageState extends State<CaptionPage> {
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  PageController pageController = PageController(initialPage: 0);

  Future<File?> assetEntityToFile(AssetEntity assetEntity) async {
    final File? file = await assetEntity.file;
    return file;
  }

  Future<File?> compressImage(File file) async {
    try {
      final directory = await getTemporaryDirectory();
      final targetPath =
          '${directory.absolute.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

      final XFile? xFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 88,
        minWidth: 1000,
        minHeight: 1000,
      );

      if (xFile != null) {
        return File(xFile.path);
      }
      return null;
    } catch (e) {
      print("Error during image compression: $e");
      return null;
    }
  }

  void createPost(String uid) async {
    setState(() {
      _isLoading = true;
    });

    try {
      File? originalFile = await assetEntityToFile(widget.selectedMedia!);
      File? mediaFile;

      if (widget.mediaType == MediaType.photo && originalFile != null) {
        mediaFile = await compressImage(originalFile);
      } else {
        mediaFile = originalFile; // No compression for videos
      }

      if (mediaFile != null) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        double latitude = position.latitude;
        double longitude = position.longitude;

        String res = await FireStoreMethods().createPost(
          uid,
          _descriptionController.text,
          widget.mediaType == MediaType.photo ? "photos" : "videos",
          mediaFile,
          latitude,
          longitude,
        );

        if (res == "success") {
          showSnackBar('Posted!', context);
          Navigator.of(context).popUntil((route) => route.isFirst);
          pageController.jumpToPage(0);
        } else {
          showSnackBar(res, context);
        }
      } else {
        showSnackBar('Media processing failed.', context);
      }
    } catch (err) {
      showSnackBar(err.toString(), context);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model.User? user = Provider.of<UserProvider>(context).getUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Post'),
      ),
      body: Column(
        children: [
          // Display the selected media as a thumbnail
          Container(
            padding: const EdgeInsets.all(8.0),
            child: FutureBuilder<File?>(
              future: widget.selectedMedia!.file,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.data != null) {
                  // For videos, display first frame or placeholder
                  if (widget.mediaType == MediaType.video) {
                    return FutureBuilder<Uint8List?>(
                      future: widget.selectedMedia!.thumbnailData,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.data != null) {
                          return Image.memory(
                            snapshot.data!,
                            width: 150, // Adjust the size as needed
                            height: 150,
                            fit: BoxFit.cover,
                          );
                        } else {
                          // Placeholder for video
                          return Container(
                            width: 150,
                            height: 150,
                            color: Colors.black,
                            child: Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 50,
                            ),
                          );
                        }
                      },
                    );
                  }

                  // For photos, display the image file
                  return Image.file(
                    snapshot.data!,
                    width: 150, // Adjust the size as needed
                    height: 150,
                    fit: BoxFit.cover,
                  );
                } else {
                  // Handle loading state or nullable file
                  return const CircularProgressIndicator();
                }
              },
            ),
          ),
          // Caption input field
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Caption',
              hintText: 'Write a caption...',
              border: OutlineInputBorder(),
            ),
            maxLines: null,
          ),
          // Post button
          ElevatedButton(
            onPressed: _isLoading ? null : () => createPost(user!.uid),
            child: _isLoading
                ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : Text('Post'),
          ),
        ],
      ),
    );
  }

  void showSnackBar(String content, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(content)),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: PhotosPage(),
  ));
}

class VideosPage extends StatefulWidget {
  const VideosPage({Key? key}) : super(key: key);

  @override
  _VideosPageState createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  List<AssetEntity> _galleryVideos = [];
  AssetEntity? _selectedVideo;
  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _fetchVideos() async {
    final PermissionState permission =
        await PhotoManager.requestPermissionExtend();
    if (permission == PermissionState.authorized ||
        permission == PermissionState.limited) {
      final List<AssetPathEntity> albums =
          await PhotoManager.getAssetPathList(type: RequestType.video);
      if (albums.isNotEmpty) {
        final List<AssetEntity> videos =
            await albums.first.getAssetListPaged(page: 0, size: 100);
        setState(() {
          _galleryVideos = videos;
          if (videos.isNotEmpty) _selectedVideo = videos.first;
        });
        _loadSelectedVideo();
      }
    } else {
      PhotoManager.openSetting();
    }
  }

  void _loadSelectedVideo() async {
    if (_selectedVideo == null) return;

    final file = await _selectedVideo!.file;
    _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.file(file!)
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController!.play();
      });
  }

  void _onVideoTap(AssetEntity video) {
    setState(() {
      _selectedVideo = video;
    });
    _loadSelectedVideo();
  }

  Widget _buildVideoPlayer() {
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      return SizedBox.shrink(); // or some placeholder
    }
    return AspectRatio(
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      child: VideoPlayer(_videoPlayerController!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_selectedVideo != null)
            Container(
              height: MediaQuery.of(context).size.height * 0.48,
              child: _buildVideoPlayer(),
            ),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4.0,
                mainAxisSpacing: 4.0,
              ),
              itemCount: _galleryVideos.length,
              itemBuilder: (context, index) {
                final asset = _galleryVideos[index];
                final isSelected = _selectedVideo == asset;
                return GestureDetector(
                  onTap: () => _onVideoTap(asset),
                  child: Opacity(
                    opacity: isSelected ? 0.5 : 1,
                    child: FutureBuilder<Uint8List?>(
                      future: asset
                          .thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.data != null) {
                          return Image.memory(snapshot.data!,
                              fit: BoxFit.cover);
                        }
                        return Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_selectedVideo != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CaptionPage(
                  selectedMedia:
                      _selectedVideo, // Assuming _selectedVideo is an AssetEntity
                  mediaType: MediaType.video,
                ),
              ),
            );
          }
        },
        label: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Next',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.navigate_next,
              color: Colors.white,
            ),
          ],
        ),
        backgroundColor: highlightColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }
}

class CreateUpdatePage extends StatefulWidget {
  @override
  _CreateUpdatePageState createState() => _CreateUpdatePageState();
}

class _CreateUpdatePageState extends State<CreateUpdatePage> {
  final TextEditingController _captionController = TextEditingController();
  bool isKeyboardVisible = false;
  bool _isLoading = false;
  PageController pageController = PageController(initialPage: 0);
  // Add more controllers and state variables for polls, Q&A as needed

  @override
  void initState() {
    super.initState();
    // Set up listeners or any initial data fetch if required
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _postUpdate(String uid) async {
    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      double latitude = position.latitude;
      double longitude = position.longitude;

      String res = await FireStoreMethods().createTextPost(
        uid,
        _captionController.text,
        "updates",
        latitude,
        longitude,
      );

      if (res == "success") {
        showSnackBar('Posted!', context);
        Navigator.of(context).popUntil((route) => route.isFirst);
        pageController.jumpToPage(0);
      } else {
        showSnackBar(res, context);
      }
    } catch (err) {
      showSnackBar(err.toString(), context);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final model.User? user = Provider.of<UserProvider>(context).getUser;
    isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom != 0;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _captionController,
              keyboardType: TextInputType.multiline,
              maxLines: null, // This allows for multi-line input
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          ElevatedButton(
            onPressed: _isLoading ? null : () => _postUpdate(user!.uid),
            child: _isLoading
                ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : Text('Post'),
          ),
          // This container will hold our features
          AnimatedContainer(
            duration: Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: EdgeInsets.only(
              bottom: isKeyboardVisible
                  ? MediaQuery.of(context).viewInsets.bottom
                  : 0,
            ),
            child: _buildFeatureBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBar() {
    // Replace these with actual interactive features.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(Icons.poll),
          onPressed: () {
            // Implement your poll creation logic
          },
        ),
        IconButton(
          icon: Icon(Icons.question_answer),
          onPressed: () {
            // Implement your Q&A session logic
          },
        ),
      ],
    );
  }
}

Future<void> requestPermission() async {
  final androidInfo = await DeviceInfoPlugin().androidInfo;

  late final Map<Permission, PermissionStatus> statusess;

  if (androidInfo.version.sdkInt <= 32) {
    statusess = await [
      Permission.storage,
    ].request();
  } else {
    statusess = await [Permission.photos, Permission.notification].request();
  }
}
