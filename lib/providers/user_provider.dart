import 'package:flutter/material.dart';
import 'package:localink_sm/models/user.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/resources/auth_methods.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  final AuthMethods _authMethods = AuthMethods();

  User? get getUser => _user;

  Future<void> refreshUser() async {
  try {
    User user = await _authMethods.getUserDetails();
    _user = user;
    notifyListeners();
  } catch (e) {
    print("Error refreshing user: $e");
  }
}


  
}
