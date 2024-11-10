import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/models/report.dart';
import 'package:localink_sm/providers/user_provider.dart';
import 'package:localink_sm/resources/storage_methods.dart';
import 'package:localink_sm/screens/login_screen.dart';
import 'package:localink_sm/services/visiting_status.dart';
import 'package:localink_sm/utils/service_locator.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'firebase_options.dart';
import 'package:localink_sm/responsive/mobile_screen_layout.dart';
import 'package:localink_sm/responsive/responsive_layout_screen.dart';
import 'package:localink_sm/responsive/web_screen_layout.dart';
import 'package:localink_sm/utils/colors.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  setupLocator();  // Set up the location service

  runApp(const MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'LocaLink',
        theme: ThemeData.dark()
            .copyWith(scaffoldBackgroundColor: darkBackgroundColor),
        home: const Home(),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver{
  double shakeThresholdGravity = 16.7;
  int shakeSlopTimeMS = 3500;
  int shakeCountResetTime = 3000;
  Uint8List? referencePhoto;
    final VisitingStatus visitingStatus = VisitingStatus();


  int mShakeTimestamp = DateTime.now().millisecondsSinceEpoch;
  int shakeCount = 0;

  Future<String> createReport(
      String name, Uint8List referencePhoto, String description) async {
    String res = "Some error occurred";
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        res = "User not logged in";
        return res;
      }
      String userId = currentUser.uid;
      // Assuming you have a method to upload images and return the URL
      String photoUrl = await StorageMethods()
          .uploadImageToStorage('reportPhotos', referencePhoto, false);

      String reportId = const Uuid().v1(); // Unique ID for the report

      // Constructing the Report object. Make sure you have a Report class defined as per previous instructions
      Report report = Report(
        userId: userId,
        name: name,
        referencePhoto: photoUrl, // URL returned after uploading the photo
        description: description,
      );

      // Save the report to Firestore
      FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .set(report.toJson());
      res = "Success";
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

   /*  SensorsPlatform.instance.accelerometerEvents
        .listen((AccelerometerEvent event) {
      var x = event.x;
      var y = event.y;
      var z = event.z;

      double gX = x / 9.80665;
      double gY = y / 9.80665;
      double gZ = z / 9.80665;
      double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

      if (gForce > shakeThresholdGravity) {
        var now = DateTime.now().millisecondsSinceEpoch;

        if (mShakeTimestamp + shakeSlopTimeMS > now) {
          return;
        }

        if (mShakeTimestamp + shakeCountResetTime < now) {
          shakeCount = 0;
        }

        mShakeTimestamp = now;
        shakeCount++;

        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor:
                  darkLBackgroundColor, // Set the background color here
              title: const Text(
                'Report Issue',
                style: TextStyle(
                    color:
                        highlightColor), // Adjusted for visibility against the new background
              ),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: "Enter your name",
                        hintStyle: TextStyle(
                            color: primaryColor), // Adjusted for visibility
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: primaryColor), // Adjusted for visibility
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText: "Describe the issue",
                        hintStyle: TextStyle(
                            color: primaryColor), // Adjusted for visibility
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: primaryColor), // Adjusted for visibility
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final Uint8List imageData = await image.readAsBytes();
                          setState(() {
                            referencePhoto = imageData;
                          });
                        }
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: primaryColor, // Adjusted for visibility
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: referencePhoto == null
                            ? const Icon(Icons.add_a_photo,
                    p            color:
                                    secondaryColor) // Adjusted for visibility
                            : Image.memory(referencePhoto!, fit: BoxFit.cover),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                        color: primaryColor), // Adjusted for visibility
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  child: const Text(
                    'Submit',
                    style: TextStyle(
                        color: primaryColor), // Adjusted for visibility
                  ),
                  onPressed: () async {
                    if (_nameController.text.isNotEmpty &&
                        _descriptionController.text.isNotEmpty &&
                        referencePhoto != null) {
                      String result = await createReport(
                        _nameController.text,
                        referencePhoto!,
                        _descriptionController.text,
                      );

                      if (result == "Success") {
                      } else {}
                    } else {}

                    // ignore: use_build_context_synchronously
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }); */
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (state == AppLifecycleState.resumed) {
      userProvider.setUserOnline();
    } else if (state == AppLifecycleState.paused) {
      userProvider.setUserOffline();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => Scaffold(
        body: StreamBuilder(
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              if (snapshot.hasData) {
                return const ResponsiveLayout(
                  mobileScreenLayout: MobileScreenLayout(),
                  webScreenLayout: WebScreenLayout(),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Text('${snapshot.error}'),
                );
              }
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
