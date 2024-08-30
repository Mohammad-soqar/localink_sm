import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:localink_sm/models/user.dart' as model;
import 'package:localink_sm/screens/event_form_signup.dart';
import 'package:localink_sm/screens/locamap_screen.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetails extends StatefulWidget {
  final String eventId;

  const EventDetails({Key? key, required this.eventId}) : super(key: key);

  @override
  _EventDetailsState createState() => _EventDetailsState();
}

class _EventDetailsState extends State<EventDetails> {
  bool isLoading = false;
  DocumentSnapshot<Map<String, dynamic>>? event;
  int _currentPage = 0;
  model.User? userData;
  bool isSignedUp = false;

  PageController _pageController = PageController();

  void _launchDirections(double latitude, double longitude) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
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

  Future<void> _checkIfSignedUp() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    var eventDoc =
        FirebaseFirestore.instance.collection('events').doc(widget.eventId);
    var attendeesCollection = eventDoc.collection('attendees');

    var attendeeDoc = await attendeesCollection.doc(userId).get();
    setState(() {
      isSignedUp = attendeeDoc.exists;
    });
  }

 Future<void> _signUpForEvent() async {
  try {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    var eventDoc =
        FirebaseFirestore.instance.collection('events').doc(widget.eventId);
    var attendeesCollection = eventDoc.collection('attendees');

    var attendeesSnapshot = await attendeesCollection.get();
    int maxAttendees = event!['maxAttendees'];

    if (attendeesSnapshot.docs.any((doc) => doc.id == userId)) {
      showSnackBar('You are already signed up for this event.', context);
      return;
    }

    if (maxAttendees != -1 && attendeesSnapshot.docs.length >= maxAttendees) {
      showSnackBar(
          'This event has reached its maximum number of attendees.', context);
      return;
    }

    await attendeesCollection.doc(userId).set({
      'userId': userId,
      'signedUpAt': FieldValue.serverTimestamp(),
    });

    // Decrease the maxAttendees count
    if (maxAttendees != -1) {
      await eventDoc.update({
        'maxAttendees': FieldValue.increment(-1),
      });
    }

    showSnackBar('You have successfully signed up for the event.', context);
    setState(() {
      isSignedUp = true;
    });

    // Navigate back to the LocaMap page and remove previous routes
  } catch (e) {
    showSnackBar(e.toString(), context);
  }
}

Future<void> _unsubscribeFromEvent() async {
  try {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    var eventDoc =
        FirebaseFirestore.instance.collection('events').doc(widget.eventId);
    var attendeesCollection = eventDoc.collection('attendees');

    await attendeesCollection.doc(userId).delete();

    // Increase the maxAttendees count
    if (event!['maxAttendees'] != -1) {
      await eventDoc.update({
        'maxAttendees': FieldValue.increment(1),
      });
    }

    showSnackBar('You have successfully unsubscribed from the event.', context);
    setState(() {
      isSignedUp = false;
    });

    // Navigate back to the LocaMap page and remove previous routes
 
  } catch (e) {
    showSnackBar(e.toString(), context);
  }
}


  void _navigateToSignUpForm() async {
    bool? success = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventSignUpForm(event: event!),
      ),
    );

    if (success == true) {
      setState(() {
        isSignedUp = true;
      });

      // Navigate back to the LocaMap page and remove previous routes
      Navigator.of(context).popUntil((route) => route.isFirst);
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
      _checkIfSignedUp();
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
  void initState() {
    super.initState();
    _getEventData(widget.eventId);
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!.round();
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
         color: darkLBackgroundColor,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
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
                                    backgroundImage:
                                        NetworkImage(event!['pinUrl']),
                                  ),
                                  title: Text(userData?.username ?? 'No Title'),
                                ),
                              ),
                             
                            ],
                          ),
                          event!['imageUrls'] != null
                              ? Padding(
                                  padding: const EdgeInsets.all(0.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(
                                          (event!['imageUrls'] as List<dynamic>)
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
                                ),
                          SizedBox(height: 10),
                          Text(
                            event!['name'] ?? 'No Title',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            event!['description'] ?? 'No Description',
                            style: const TextStyle(
                              fontSize: 14,
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
                                        _launchDirections(event!['latitude'],
                                            event!['longitude']);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: highlightColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16.0),
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
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: _buildSignUpButton(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(child: Text('Event not found')),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: highlightColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
            child: Text(
              'Loading...',
              style: TextStyle(
                color: primaryColor,
                fontSize: 16,
              ),
            ),
          );
        }

        var event = snapshot.data!;
        var extraFields = event['extraFields'] ?? [];
        int maxAttendees = event['maxAttendees'] ?? -1;
        bool isFull = maxAttendees != -1 && maxAttendees <= 0;

        return ElevatedButton(
          onPressed: isSignedUp
              ? _unsubscribeFromEvent
              : (isFull
                  ? null
                  : (extraFields.isNotEmpty)
                      ? _navigateToSignUpForm
                      : _signUpForEvent),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSignedUp ? Colors.red : highlightColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
          child: Text(
            isSignedUp
                ? 'Unsubscribe'
                : (isFull
                    ? 'Event Full'
                    : (extraFields.isNotEmpty)
                        ? 'Fill Form'
                        : 'Sign Up'),
            style: TextStyle(
              color: primaryColor,
              fontSize: 16,
            ),
          ),
        );
      },
    );
  }
}
