import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/screens/likes_history.dart';
import 'package:localink_sm/screens/save_posts_screen.dart';
import 'package:localink_sm/utils/colors.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
        User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your activity'),
        backgroundColor: darkBackgroundColor, // Assuming a dark theme from the screenshot
      ),
      body: Container(
        color: darkBackgroundColor, // Assuming a dark theme from the screenshot
        child: ListView(
          children: <Widget>[
             const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'One place to manage your activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
             const Padding(
              padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Text(
                'View and manage your interactions, content and account activity.',
                style: TextStyle(color: Color.fromARGB(255, 49, 42, 42)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark, color: Colors.white),
              title: const Text('Saved Posts', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SavedPostsPage(userId: currentUser!.uid,),
                    ),
                  ),
            ),
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.white),
              title: const Text('Likes', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => LikesPage(userId: currentUser!.uid,),
                    ),
                  ),
            ),
            ListTile(
              leading: const Icon(Icons.comment, color: Colors.white),
              title: const Text('Comments', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: () {
              },
            ),
             const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.white),
              title: const Text('Recently deleted', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: () {
              },
            ),
          
          ],
        ),
      ),
    );
  }
}
