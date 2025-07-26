import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/providers/user_provider.dart';
import 'package:localink_sm/screens/verify_email_screen.dart';
import 'package:localink_sm/utils/global_variables.dart';
import 'package:provider/provider.dart';

class ResponsiveLayout extends StatefulWidget {
  final Widget webScreenLayout;
  final Widget mobileScreenLayout;
  const ResponsiveLayout(
      {super.key,
      required this.webScreenLayout,
      required this.mobileScreenLayout});

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  bool _isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;
    if (_isEmailVerified) {
      print("Email is verified");
    } else {
      print("Email is not verified");
    }
    addData();
  }

  addData() async {
    UserProvider userProvider =
        Provider.of<UserProvider>(context, listen: false);
    await userProvider.refreshUser();
  }

  @override
  Widget build(BuildContext context) => _isEmailVerified
      ? const VerifyEmailScreen()
      : LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > webScreenSize) {
              return widget.webScreenLayout;
            }
            //mobilescreen
            return widget.mobileScreenLayout;
          },
        );
}
