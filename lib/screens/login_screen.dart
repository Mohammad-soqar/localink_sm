import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:localink_sm/resources/auth_methods.dart';
import 'package:localink_sm/responsive/mobile_screen_layout.dart';
import 'package:localink_sm/responsive/responsive_layout_screen.dart';
import 'package:localink_sm/responsive/web_screen_layout.dart';
import 'package:localink_sm/screens/signup_screen.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/utils.dart';
import 'package:localink_sm/widgets/text_field_input.dart';

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

  void loginUser() async {


    
    setState(() {
      _isLoading = true;
    });
    String res = await AuthMethods().loginUser(
        email: _emailController.text, password: _passwordController.text);

    if (res == "success") {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => const ResponsiveLayout(
                mobileScreenLayout: MobileScreenLayout(),
                webScreenLayout: WebScreenLayout(),
              )));
    } else {
      showSnackBar(res, context);
    }
    setState(() {
      _isLoading = false;
    });
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
