import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:localink_sm/models/user.dart';
import 'package:localink_sm/resources/firestore_methods.dart';
import 'package:localink_sm/screens/comment_screen.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/providers/user_provider.dart';
import 'package:localink_sm/widgets/like_animation.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class EventCard extends StatefulWidget {
  final String eventId;

  const EventCard({Key? key, required this.eventId}) : super(key: key);

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool isLoading = false;
  model.User? userData;
  DocumentSnapshot<Map<String, dynamic>>? event;

  @override
  void initState() {
    super.initState();
  }

  _fetchUserData(String uid) async {
    try {
      DocumentSnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      userData = model.User.fromSnap(userSnapshot);
      if (mounted) {
        setState(() {});
      }
    } catch (err) {
      print('Error fetching user data: $err');
    }
  }

  Future<void> _getEventData(String eventId) async {
    setState(() {
      isLoading = true;
    });

    try {
      var eventSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();

      setState(() {
        event = eventSnap;
        isLoading = false;
      });

      _fetchUserData(event?['organizer']);
    } catch (e) {
      showSnackBar(
        e.toString(),
        context,
      );

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : event != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(event!['pinUrl']),
                              ),
                              title: Text(userData?.username ?? 'No Title'),
                            ),
                          ),
                        ],
                      ),
                      event!['imageUrls'] != null
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(
                                  (event!['imageUrls'] as List<dynamic>)[0],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text('No Images Available'),
                            ),
                      /* event!['imageUrls'] != null
                          ? Padding(
                              padding: const EdgeInsets.all(0.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    height: 200,
                                    child: PageView.builder(
                                      controller:
                                          _pageController, // Assign the controller
                                      itemCount: (event!['imageUrls']
                                              as List<dynamic>)
                                          .length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4.0),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            child: Image.network(
                                              (event!['imageUrls']
                                                  as List<dynamic>)[index],
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      (event!['imageUrls']
                                              as List<dynamic>)
                                          .length,
                                      (index) => Container(
                                        width: 8.0,
                                        height: 8.0,
                                        margin: EdgeInsets.symmetric(
                                            horizontal: 4.0),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: index == _currentPage
                                              ? highlightColor
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text('No Images Available'),
                            ), */
                      SizedBox(height: 10),
                      Text(
                        event!['name'] ?? 'No Title',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                   ;
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: highlightColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                  ),
                                  child: Text(
                                    'Directions',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                  width:
                                      16), // Add some spacing between the buttons
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    // Add logic for signing up for the event
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: highlightColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                  ),
                                  child: Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(child: Text('event not found')),
      ),
    );
  }
}
