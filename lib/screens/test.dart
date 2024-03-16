/* import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:localink_sm/screens/create_post.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class MediaGrid extends StatefulWidget {
  @override
  _MediaGridState createState() => _MediaGridState();
}

class _MediaGridState extends State<MediaGrid> {
  List<AssetEntity> _mediaAssets = []; // Changed to AssetEntity list
  AssetEntity? _selectedImage;
  int currentPage = 0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchNewMedia();
  }

  _handleScrollEvent(ScrollNotification scroll) {
    if (scroll.metrics.pixels / scroll.metrics.maxScrollExtent > 0.75 &&
        !isLoading) {
      _fetchNewMedia();
    }
  }

  _fetchNewMedia() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    await requestPermission();

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        hasAll: true, type: RequestType.all);
    if (paths.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    final recentAlbum = paths.firstWhere((album) => album.name == "Recent",
        orElse: () => paths.first);
    final media =
        await recentAlbum.getAssetListPaged(page: currentPage, size: 60);

    if (_selectedImage == null && media.isNotEmpty) {
      setState(() {
        _selectedImage = media.firstWhere(
          (asset) => asset.type == AssetType.image,
          orElse: () => media.first,
        );
      });
    }

    setState(() {
      _mediaAssets.addAll(media);
      currentPage++;
      isLoading = false;
    });
  }

  void _toggleImageSelection(AssetEntity asset) {
    setState(() => _selectedImage = asset);
  }

  Widget _buildSelectedImageWidget() {
    if (_selectedImage == null) return SizedBox.shrink();

    return Container(
      height: MediaQuery.of(context).size.height * 0.48,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: FutureBuilder<File?>(
        future: _selectedImage!.file,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data != null) {
            return Image.file(snapshot.data!, fit: BoxFit.cover);
          } else {
            return CircularProgressIndicator();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children: [
        _buildSelectedImageWidget(),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scroll) {
              _handleScrollEvent(scroll);
              return true;
            },
            child: GridView.builder(
              itemCount: _mediaAssets.length,
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
              itemBuilder: (BuildContext context, int index) {
                final asset = _mediaAssets[index];
                final isSelected = _selectedImage == asset;
                return GestureDetector(
                  onTap: () => _toggleImageSelection(asset),
                  child: GridTile(
                    key: ValueKey(
                        "${asset.id}_${isSelected ? 'selected' : 'unselected'}"),
                    child: FutureBuilder<Uint8List?>(
                      future: asset
                          .thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                      builder: (BuildContext context,
                          AsyncSnapshot<Uint8List?> snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.data != null) {
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: Image.memory(snapshot.data!,
                                    fit: BoxFit.cover),
                              ),
                              if (asset.type == AssetType.video)
                                const Align(
                                  alignment: Alignment.bottomRight,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.only(right: 5, bottom: 5),
                                    child: Icon(Icons.videocam,
                                        color: Colors.white),
                                  ),
                                ),
                              if (isSelected)
                                const Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Icon(Icons.check_circle,
                                      color: highlightColor),
                                ),
                            ],
                          );
                        }
                        return Container();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CaptionPage(
                  selectedImage: _selectedImage,
                  postTypeName: "photos",
                ),
              ),
            );
          },
          child: Text('Next'),
        ),
      ],
    ),
    );
  }

  Future<void> requestPermission() async {
    final status = await [Permission.photos].request();
    print(status); // Log the permission status
  }
}
 */


/* import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key});

  @override
  _PhotosPageState createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  List<AssetEntity> _mediaAssets = [];
  AssetEntity? _selectedImage;
  File? _selectedImageFile; // To hold the cropped image as a File
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

    final recentAlbum = paths.firstWhere(
      (album) => album.name == "Recent",
      orElse: () => paths.first,
    );

    final List<AssetEntity> media = await recentAlbum.getAssetListPaged(page: currentPage, size: 60);

    setState(() {
      _mediaAssets.addAll(media);
      currentPage++;
      isLoading = false;
    });
  }

  Future<void> _cropImage(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) return;

    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatioPresets: [CropAspectRatioPreset.square],
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (croppedFile != null) {
      File croppedImageFile = File(croppedFile.path);
      setState(() => _selectedImageFile = croppedImageFile);
    }
  }

  // New: Automatically crop the image if it exceeds square dimensions
  Future<void> _autoCropImage(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) return;

    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatioPresets: [CropAspectRatioPreset.square],
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Crop',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: 'Adjust Crop',
          aspectRatioLockEnabled: true,
          rotateButtonsHidden: true,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );

    if (croppedFile != null) {
      File croppedImageFile = File(croppedFile.path);
      setState(() => _selectedImageFile = croppedImageFile);
    }
  }

  Widget _buildSelectedImageWidget() {
    return FutureBuilder<File?>(
      future: _selectedImageFile != null ? Future.value(_selectedImageFile) : _selectedImage?.file,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return Image.file(snapshot.data!, fit: BoxFit.cover);
        } else {
          return CircularProgressIndicator();
        }
      },
    );
  }

  // New: Proceed to next page, ensuring image cropping if necessary
  void _proceedToNext() async {
    if (_selectedImageFile == null && _selectedImage != null) {
      // Automatically crop the image if it's not manually cropped
      await _autoCropImage(_selectedImage!);
    }
    // Proceed to next page logic here
    // Example: Navigator.push(...)
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
            actions: [
              // New: Edit button to manually crop the image
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () => _selectedImage != null ? _cropImage(_selectedImage!) : null,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildSelectedImageWidget(),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(top: 8.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 3.0,
                crossAxisSpacing: 3.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final asset = _mediaAssets[index];
                  return GestureDetector(
                    onTap: () {}, // Removed cropping from here
                    child: GridTile(
                      key: ValueKey("${asset.id}"),
                      child: FutureBuilder<Uint8List?>(
                        future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                        builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
                          return snapshot.hasData
                              ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                              : Container(color: Colors.grey[200]);
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
        onPressed: _proceedToNext, // Changed to call _proceedToNext
        label: const Text('Next'),
        icon: const Icon(Icons.navigate_next),
      ),
    );
  }
}


 */
