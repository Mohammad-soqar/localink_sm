import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/screens/likes_history.dart';
import 'package:localink_sm/screens/save_posts_screen.dart';
import 'package:localink_sm/utils/colors.dart';

class ActivityPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
        User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your activity'),
        backgroundColor: darkBackgroundColor, // Assuming a dark theme from the screenshot
      ),
      body: Container(
        color: darkBackgroundColor, // Assuming a dark theme from the screenshot
        child: ListView(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'One place to manage your activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Text(
                'View and manage your interactions, content and account activity.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ListTile(
              leading: Icon(Icons.bookmark, color: Colors.white),
              title: Text('Saved Posts', style: TextStyle(color: Colors.white)),
              trailing: Icon(Icons.chevron_right, color: Colors.white),
              onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SavedPostsPage(userId: currentUser!.uid,),
                    ),
                  ),
            ),
            ListTile(
              leading: Icon(Icons.favorite, color: Colors.white),
              title: Text('Likes', style: TextStyle(color: Colors.white)),
              trailing: Icon(Icons.chevron_right, color: Colors.white),
              onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => LikesPage(userId: currentUser!.uid,),
                    ),
                  ),
            ),
            ListTile(
              leading: Icon(Icons.comment, color: Colors.white),
              title: Text('Comments', style: TextStyle(color: Colors.white)),
              trailing: Icon(Icons.chevron_right, color: Colors.white),
              onTap: () {
                // Navigate to Comments page
              },
            ),
            // ... add other ListTile widgets for Tags, Sticker responses, etc.
            Divider(color: Colors.grey),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.white),
              title: Text('Recently deleted', style: TextStyle(color: Colors.white)),
              trailing: Icon(Icons.chevron_right, color: Colors.white),
              onTap: () {
                // Navigate to Recently Deleted page
              },
            ),
          
            // ... add other ListTile widgets for shared content sections.
          ],
        ),
      ),
    );
  }
}
