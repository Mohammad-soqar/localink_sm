import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/responsive/mobile_screen_layout.dart';
import 'package:localink_sm/responsive/responsive_layout_screen.dart';
import 'package:localink_sm/responsive/web_screen_layout.dart';
import 'package:localink_sm/screens/add_post_screen.dart';
import 'package:localink_sm/utils/colors.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isButtonDisabled = true;
  bool _isButtonPressed = false;
  int _remainingTime = 60;
  bool _isNextButtonEnabled = false;
  bool _isEmailVerified = false;
  Timer? timer;


  @override
  void initState() {
    super.initState();
    _isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;

    if(!_isEmailVerified){
      sendVerificationEmail();

      timer = Timer.periodic(
        Duration(seconds: 3),
         (_) => checkEmailVerified(),);
    }
    startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future checkEmailVerified() async{
    await FirebaseAuth.instance.currentUser!.reload();

    setState(() {
      _isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;
    });

    if(_isEmailVerified) timer?.cancel();
  }


  void startTimer() {
    // Start a countdown timer to update remaining time every second
    Timer.periodic(Duration(seconds: 1), (Timer timer) {
      if (_isButtonPressed && _remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        // Enable the button after a minute and reset the timer
        setState(() {
          _isButtonDisabled = false;
          _isButtonPressed = false;
          _remainingTime = 60;
        });
        timer.cancel();
      }
    });
  }

  void navigateToNextScreen() {
    // Your logic to navigate to the next screen goes here
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ResponsiveLayout(
          mobileScreenLayout: MobileScreenLayout(),
          webScreenLayout: WebScreenLayout(),
        ),
      ),
    );
  }

  Future<void> sendVerificationEmail() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null && !user.emailVerified) {
      try {
        setState(() {
          _isButtonDisabled = true;
          _isButtonPressed = true;
        });

        // Start or restart the timer
        startTimer();
        await user.sendEmailVerification();

        print("Verification email sent successfully");

        // Add a delay to allow time for the verification status to update
        await Future.delayed(
            Duration(seconds: 5)); // Adjust the duration as needed

        // Refresh the user to get the updated emailVerified status
        await user.reload();
        user = FirebaseAuth.instance.currentUser;

        if (user != null && user.emailVerified) {
          print("Email verification status updated successfully");
        } else {
          print("Error: Email verification failed or not updated");
        }
      } catch (e) {
        print("Error sending verification email: $e");
      }
    } else {
      print("User is already verified or not signed in");
    }
  }

  @override
  Widget build(BuildContext context)=> _isEmailVerified? const ResponsiveLayout(
          mobileScreenLayout: MobileScreenLayout(),
          webScreenLayout: WebScreenLayout(),
        ): 
     Scaffold(
      appBar: AppBar(
        backgroundColor: darkBackgroundColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin:
                  EdgeInsets.only(top: 30.0), // Adjust the top margin as needed
              child: SvgPicture.asset(
                'assets/logo-with-name-H.svg',
                height: 20,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
                child: SvgPicture.asset(
              'assets/icons/email.svg',
              width: 150,
              height: 150,
            )),
            const SizedBox(
              height: 20,
            ),
            const Text(
              'Email Verification',
              style: TextStyle(
                fontSize: 28,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(
              height: 30,
            ),
            const Text(
              'an email with verification link have been sent to you!',
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(
              height: 60,
            ),
           
            
            Container(
              margin: EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: _isButtonDisabled ? null : sendVerificationEmail,
                style: ElevatedButton.styleFrom(
                  primary: primaryColor,
                  onPrimary: highlightColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: EdgeInsets.symmetric(vertical: 6),
                ),
                child: const Text(
                  'Send Again',
                  style: TextStyle(fontSize: 28),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '$_remainingTime seconds remaining',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

