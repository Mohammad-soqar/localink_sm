import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _isPrivateProfile = false;
  bool _isDarkTheme = false;
  

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _isPrivateProfile = prefs.getBool('isPrivateProfile') ?? false;
      _isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('isPrivateProfile', _isPrivateProfile);
    await prefs.setBool('isDarkTheme', _isDarkTheme);
  }

  void _toggleNotifications(bool value) {
    setState(() {
      _notificationsEnabled = value;
    });
    _saveSettings();
  }

  void _togglePrivacy(bool value) {
    setState(() {
      _isPrivateProfile = value;
    });
    _saveSettings();
  }

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkTheme = value;
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('Enable Notifications'),
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
          ),
          SwitchListTile(
            title: Text('Private Profile'),
            value: _isPrivateProfile,
            onChanged: _togglePrivacy,
          ),
          SwitchListTile(
            title: Text('Dark Theme'),
            value: _isDarkTheme,
            onChanged: _toggleTheme,
          ),
        ],
      ),
    );
  }
}
