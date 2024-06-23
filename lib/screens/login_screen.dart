import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:localink_sm/providers/user_provider.dart';
import 'package:localink_sm/resources/auth_methods.dart';
import 'package:localink_sm/responsive/mobile_screen_layout.dart';
import 'package:localink_sm/responsive/responsive_layout_screen.dart';
import 'package:localink_sm/responsive/web_screen_layout.dart';
import 'package:localink_sm/screens/signup_screen.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/utils.dart';
import 'package:localink_sm/widgets/text_field_input.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    super.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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


  void loginUser() async {
    setState(() {
      _isLoading = true;
    });

    String res = await AuthMethods().loginUser(
        email: _emailController.text, password: _passwordController.text);

    if (!mounted) return;

    if (res == "success") {
      // Save the device token after a successful login
      String userId = FirebaseAuth.instance.currentUser!.uid;
      await saveDeviceToken(userId);
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => const ResponsiveLayout(
            mobileScreenLayout: MobileScreenLayout(),
            webScreenLayout: WebScreenLayout(),
          ),
        ));
      }
    } else {
      showSnackBar(res, context);
    }

    // Again, ensure the widget is still mounted before calling setState
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void navigatToSignUp() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const SignupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 32),
          width: double.infinity,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            //svg image
            Flexible(child: Container(), flex: 2),
            SvgPicture.asset('assets/logo-with-name-H.svg', height: 200),
            const SizedBox(height: 24),
            //email
            TextFieldInput(
                textEditingController: _emailController,
                hintText: 'Enter Your Email',
                textInputType: TextInputType.emailAddress),
            const SizedBox(height: 24),
            //password
            TextFieldInput(
                textEditingController: _passwordController,
                isPass: true,
                hintText: 'Enter Your Password',
                textInputType: TextInputType.text),
            const SizedBox(height: 24),

            //button login
            InkWell(
              onTap: loginUser,
              child: Container(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: primaryColor,
                        ),
                      )
                    : const Text('Log in'),
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
                  child: const Text("Don't have an account?"),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                  ),
                ),
                GestureDetector(
                  onTap: navigatToSignUp,
                  child: Container(
                    child: const Text(
                      "Sign Up",
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
          ]),
        ),
      ),
    );
  }
}
