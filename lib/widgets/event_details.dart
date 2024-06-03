import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:localink_sm/models/user.dart' as model;
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
                        // Add other event details here
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
                                        borderRadius:
                                            BorderRadius.circular(16.0),
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
                  : Center(child: Text('Event not found')),
        ),
      ),
    );
  }
}
