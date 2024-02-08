import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/providers/user_provider.dart';
import 'package:localink_sm/screens/login_screen.dart';
import 'package:localink_sm/screens/signup_screen.dart';
import 'package:provider/provider.dart';
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

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
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: darkBackgroundColor),
        home: Builder(
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
                    child: CircularProgressIndicator(
                      color: primaryColor,
                    ),
                  );
                }
                return const LoginScreen();
              },
            ),
          ),
        ),
      ),
    );
  }
}