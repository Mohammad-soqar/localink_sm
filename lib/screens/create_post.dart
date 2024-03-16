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
          PhotosPage(),
          VideosPage(),
          TextPage(),
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
  final ScrollController _scrollController =
      ScrollController(); 

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
            backgroundColor:
                Colors.transparent,

            flexibleSpace: FlexibleSpaceBar(
              background: _selectedImage != null
                  ? _buildSelectedImageWidget()
                  : SizedBox.shrink(),
            ),
          ),
          SliverPadding(
            padding:
                EdgeInsets.only(top: 8.0),
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
                                    : Container(
                                        color: Colors
                                            .grey[200]),
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
                  selectedImage: _selectedImage,
                  postTypeName: "photos",
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
      floatingActionButtonLocation:
          FloatingActionButtonLocation.miniEndFloat,
    );
  }
}

class CaptionPage extends StatefulWidget {
  final AssetEntity? selectedImage;
  final String postTypeName;

  const CaptionPage({
    Key? key,
    required this.selectedImage,
    required this.postTypeName,
  }) : super(key: key);

  @override
  State<CaptionPage> createState() => _CaptionPageState();
}

class _CaptionPageState extends State<CaptionPage> {
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;

  File convertXFileToFile(XFile xFile) {
    return File(xFile.path);
  }

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
      File? originalFile = await assetEntityToFile(widget.selectedImage!);
      File? compressedFile;

      if (originalFile != null) {
        compressedFile = await compressImage(originalFile);
      }

      if (compressedFile != null) {
        File? mediaFile = compressedFile;

      Position position = await getLatLng();
      double latitude = position.latitude;
      double longitude = position.longitude;

      String res = await FireStoreMethods().createPost(
        uid,
        _descriptionController.text,
        widget.postTypeName,
        mediaFile,
        latitude,
        longitude,
      );

        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => FeedScreen()));
        showSnackBar('Posted!', context);
      } else {
        showSnackBar('Image compression failed.', context);
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
          // Display the selected image as a thumbnail
          if (widget.selectedImage != null)
            Container(
              padding: const EdgeInsets.all(8.0),
              child: FutureBuilder<File?>(
                future: widget.selectedImage!.file,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.data != null) {
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
// Caption input field (replace with your actual caption input field)
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Caption',
              hintText: 'Write caption',
              border: InputBorder.none,
            ),
          ),
          // Other caption-related widgets go here
          // ...
          // Post button (replace with your actual Post button)
          ElevatedButton(
            onPressed: () => createPost(
              user!.uid,
            ),
            child: Text('Post'),
          ),
        ],
      ),
    );
  }
}

void showSnackBar(String content, BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(content)));
}

void main() {
  runApp(MaterialApp(
    home: PhotosPage(),
  ));
}

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  List<AssetEntity> _galleryVideos = [];
  AssetEntity? _selectedVideo;

  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_selectedVideo != null)
            Container(
              height: MediaQuery.of(context).size.height * 0.48,
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
              child: FutureBuilder<File?>(
                future: _selectedVideo!.file,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.data != null) {
                    VideoPlayerController controller =
                        VideoPlayerController.file(snapshot.data!);

                    return FutureBuilder(
                      future: controller.initialize(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          controller.play();
                          return VideoPlayer(controller);
                        } else {
                          return CircularProgressIndicator();
                        }
                      },
                    );
                  } else {
                    // Handle loading state or nullable file
                    return CircularProgressIndicator();
                  }
                },
              ),
            ),
// GridView of videos
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4.0,
                mainAxisSpacing: 4.0,
              ),
              itemCount: _galleryVideos.length,
              itemBuilder: (context, index) {
                final asset = _galleryVideos[index];
                return GestureDetector(
                  onTap: () {},
                  child: Stack(
                    children: [
                      FutureBuilder<File?>(
                        future: asset.file,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.data != null) {
                            // You can use a placeholder icon for videos or show the first frame as an image
                            return const Icon(Icons.videocam,
                                size: 50, color: Colors.grey);
                          } else {
                            // Handle loading state or nullable file
                            return const CircularProgressIndicator();
                          }
                        },
                      ),
                      if (_selectedVideo == asset)
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: Icon(
                            Icons.check_circle,
                            color: highlightColor,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TextPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Text Content Goes Here'),
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
