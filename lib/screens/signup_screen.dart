import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:localink_sm/resources/auth_methods.dart';
import 'package:localink_sm/screens/login_screen.dart';
import 'package:localink_sm/screens/verify_email_screen.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phonenumberController = TextEditingController();
  String? userLocation;
  PhoneNumber? number;

  @override
  void initState() {
    _determinePosition();
    super.initState();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    await _getAddressFromLatLng(position.latitude, position.longitude);
  }

  Future<void> _getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);

      Placemark place = placemarks[0];
      String address = '${place.isoCountryCode}';

      setState(() {
        userLocation = address;
        String? initialCountry = address;

        try {
          PhoneNumber number = PhoneNumber(isoCode: address);
          _setPhoneNumber(number);
        } catch (phoneNumberError) {
          print('Error creating PhoneNumber: $phoneNumberError');
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void _setPhoneNumber(PhoneNumber phoneNumber) {
    setState(() {
      number = phoneNumber;
    });
  }

  Uint8List? _image;
  bool _isLoading = false;

  @override
  void dispose() {
    super.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _phonenumberController.dispose();
  }

  void selectImage() async {
    Uint8List img = await pickImage(ImageSource.gallery);
    setState(() {
      _image = img;
    });
  }

  Future<void> saveDeviceToken(String userId) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();
    print(token);

    if (token != null) {
      DocumentReference userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          throw Exception("User does not exist!");
        }

        Map<String, dynamic> userData = snapshot.data() as Map<String, dynamic>;
        List<String> tokens = List<String>.from(userData['tokens'] ?? []);

        if (!tokens.contains(token)) {
          tokens.add(token);
          transaction.update(userRef, {'tokens': tokens});
        }
      });
    }
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

  Future<Uint8List?> compressUint8List(Uint8List uint8list) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/temp_image.jpg').create();
      await file.writeAsBytes(uint8list);

      File? compressedFile = await compressImage(file);

      if (compressedFile != null) {
        return await compressedFile.readAsBytes();
      }
      return null;
    } catch (e) {
      print("Error during Uint8List image compression: $e");
      return null;
    }
  }
  Future<ui.Image> loadImageFromAssets(String assetPath) async {
    ByteData data = await rootBundle.load(assetPath);
    Uint8List bytes = data.buffer.asUint8List();
    return loadImageFromBytes(bytes);
  }

  Future<ui.Image> loadImageFromBytes(Uint8List bytes) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      return completer.complete(img);
    });
    return completer.future;
  }



  Future<void> createPins(Uint8List profileImage,String userid) async {
    // Load the pin SVG
     
     ui.Image pinImage =
            await loadImageFromAssets('assets/icons/mappin22.png');
        ui.Image userImage = await loadImageFromBytes(profileImage); 
         Uint8List normalPin =
            await createCustomMarkerImage(pinImage, userImage);
               Uint8List bluePin =
            await createCustomMarkerImage(pinImage, userImage);
      

   
    // Save pins to Firebase Storage
    await _uploadPinToStorage(normalPin, 'normal_pin.png',userid);
    await _uploadPinToStorage(bluePin, 'blue_pin.png',userid);
  }

  Future<Uint8List> createCustomMarkerImage(
      ui.Image pinImage, ui.Image userImage) async {
    final double imageSize = pinImage.width / 2;
    final Offset imageOffset = Offset((pinImage.width - imageSize) / 2,
        (pinImage.height/1.65 - imageSize) / 2 - 15);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint();

    canvas.drawImage(pinImage, Offset.zero, paint);

    final Rect ovalRect = Rect.fromCircle(
        center: imageOffset + Offset(imageSize / 2, imageSize / 2),
        radius: imageSize / 2);
    final Path ovalPath = Path()..addOval(ovalRect);
    canvas.clipPath(ovalPath, doAntiAlias: false);
    canvas.drawImageRect(
        userImage,
        Rect.fromLTRB(
            0, 0, userImage.width.toDouble(), userImage.height.toDouble()),
        ovalRect,
        paint);

    final ui.Image compositeImage =
        await recorder.endRecording().toImage(pinImage.width, pinImage.height);

    final ByteData? byteData =
        await compositeImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

Future<void> _uploadPinToStorage(Uint8List pinImage, String fileName,String userid) async {
  final tempDir = await getTemporaryDirectory();
  final filePath = '${tempDir.path}/$fileName';
  final file = File(filePath)..writeAsBytesSync(pinImage);

  // Get the current user's ID
  String userId = userid;

  // Use the user's ID to create a unique folder for each user
  await FirebaseStorage.instance.ref('user_pins/$userId/$fileName').putFile(file);
}

void signUpUser() async {
  setState(() {
    _isLoading = true;
  });

  // Compress the image first
  if (_image != null) {
    Uint8List? compressedImage = await compressUint8List(_image!);
    if (compressedImage != null) {
      _image = compressedImage;
    }
  }

  // Sign up the user
  String res = await AuthMethods().signUpUser(
    email: _emailController.text,
    password: _passwordController.text,
    phonenumber: _phonenumberController.text,
    username: _usernameController.text,
    file: _image!,
  );

  setState(() {
    _isLoading = false;
  });

  if (res != 'success') {
    showSnackBar(res, context);
  } else {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    // Create and upload pins after the user is signed up
    if (_image != null) {
      await createPins(_image!, userId);
    }

    await saveDeviceToken(userId);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => VerifyEmailScreen()),
    ); // Navigate to VerifyEmailScreen
  }
}


  void navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset(
          'assets/logo-with-name-H.svg',
          height: 20, // Adjust the size as needed
        ),
        centerTitle: true,
        automaticallyImplyLeading:
            false, // Prevents the AppBar from showing the back button automatically
      ),
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 32),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              //svg image
              Flexible(child: Container(), flex: 2),

              const SizedBox(height: 24),
              //username
              Stack(
                children: [
                  _image != null
                      ? CircleAvatar(
                          radius: 64,
                          backgroundImage: MemoryImage(_image!),
                          backgroundColor: highlightColor,
                        )
                      : const CircleAvatar(
                          radius: 64,
                          backgroundImage: NetworkImage(
                              'https://i.stack.imgur.com/l60Hf.png'),
                          backgroundColor: highlightColor,
                        ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: IconButton(
                      onPressed: selectImage,
                      icon: const Icon(Icons.add_a_photo),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Name',
                    style: TextStyle(
                        color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(
                      height:
                          8), // Provides spacing between the label and the input field.
                  TextField(
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: 'Enter Your User Name',
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: darkBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: highlightColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: highlightColor),
                      ),
                    ),
                    style: const TextStyle(
                      color: primaryColor,
                    ),
                    cursorColor: highlightColor,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Email Address',
                    style: TextStyle(
                        color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(
                      height:
                          8), // Provides spacing between the label and the input field.
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Enter Your Email',
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: darkBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: highlightColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: highlightColor),
                      ),
                    ),
                    style: const TextStyle(
                      color: primaryColor,
                    ),
                    cursorColor: highlightColor,
                  ),
                ],
              ),

              //email

              const SizedBox(height: 24),

              //phone number
              InternationalPhoneNumberInput(
                onInputChanged: (PhoneNumber number) {
                  print(number.phoneNumber);
                },
                onInputValidated: (bool value) {
                  print(value);
                },
                selectorConfig: SelectorConfig(
                  selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                  useBottomSheetSafeArea: true,
                ),
                ignoreBlank: false,
                autoValidateMode: AutovalidateMode.disabled,
                selectorTextStyle: TextStyle(color: Colors.white),
                initialValue: number,
                textFieldController: _phonenumberController,
                formatInput: true,
                keyboardType: TextInputType.numberWithOptions(
                    signed: true, decimal: true),
                inputDecoration: InputDecoration(
                  hintText: 'Enter Your Phone Number',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: darkBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: highlightColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: highlightColor),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10), // Adjust as needed
                ),
                inputBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: highlightColor),
                ),
                onSaved: (PhoneNumber number) {
                  print('On Saved: $number');
                },
                textStyle: TextStyle(
                  color: primaryColor,
                ),
              ),

              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Password',
                    style: TextStyle(
                        color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(
                      height:
                          8), // Provides spacing between the label and the input field.
                  TextField(
                    controller: _passwordController,
                    keyboardType: TextInputType.text,
                    obscureText:
                        true, // This ensures the text is obscured (for password inputs)
                    decoration: InputDecoration(
                      labelText: 'Password', // If you need a label like 'Title'
                      hintText: 'Enter Your Password',
                      hintStyle:
                          TextStyle(color: primaryColor.withOpacity(0.5)),
                      filled: true,
                      fillColor: darkBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: highlightColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                        borderSide: BorderSide(color: highlightColor),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    style: TextStyle(color: primaryColor),
                    cursorColor: highlightColor,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              //button login
              InkWell(
                onTap: signUpUser,
                child: Container(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: primaryColor,
                          ),
                        )
                      : const Text('Sign up'),
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(4),
                        ),
                      ),
                      color: highlightColor),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(child: Container(), flex: 2),
              //transition to signUp
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    child: const Text("already have an account?"),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                    ),
                  ),
                  GestureDetector(
                    onTap: navigateToLogin,
                    child: Container(
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 25,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
