import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/utils.dart';
import 'package:localink_sm/models/user.dart' as model;

class EventCard extends StatefulWidget {
  final String eventId;
  final bool? showAttendeesButton;
  final bool? viewer;
  final VoidCallback? onAttendeesButtonPressed;

  const EventCard({
    Key? key,
    required this.eventId,
    this.showAttendeesButton,
    this.onAttendeesButtonPressed, this.viewer,
  }) : super(key: key);
  
  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool isLoading = false;
  model.User? userData;
  DocumentSnapshot<Map<String, dynamic>>? event;
  PageController _pageController = PageController();
  int _currentPage = 0;

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

  Future<void> _deleteEvent(String eventId) async {
    try {
      var eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();
      if (eventDoc.exists) {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .collection('deleted_events')
            .doc(eventId)
            .set({
          ...eventDoc.data()!,
          'deletedAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .delete();

        await FirebaseFirestore.instance.collection('events').doc(eventId).set({
          'deletedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      showSnackBar(
        e.toString(),
        context,
      );
    }
  }

  void _confirmDelete(BuildContext context, String eventId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Event'),
        content: Text(
            'Are you sure you want to delete this event? You will have 10 days to restore it.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteEvent(eventId);
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
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
                          ? Column(
                              children: [
                                SizedBox(
                                  height: 200,
                                  child: PageView.builder(
                                    controller:
                                        _pageController, // Assign the controller
                                    itemCount:
                                        (event!['imageUrls'] as List<dynamic>)
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
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    (event!['imageUrls'] as List<dynamic>)
                                        .length,
                                    (index) => Container(
                                      width: 8.0,
                                      height: 8.0,
                                      margin:
                                          EdgeInsets.symmetric(horizontal: 4.0),
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
                            )
                          : Container(),
                      const SizedBox(height: 10),
                      Text(
                        event!['name'] ?? 'No Title',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            children: [
                              widget.showAttendeesButton == false
                                  ? Expanded(
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _confirmDelete(context, widget.eventId),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: highlightColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16.0),
                                          ),
                                        ),
                                        child: const Text(
                                          'Directions',
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(),
                              const SizedBox(
                                  width:
                                      16), // Add some spacing between the buttons
                               widget.viewer == false
                              ?Expanded(
                               
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _confirmDelete(context, widget.eventId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: darkBackgroundColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                  ),
                                  child: const Text(
                                    'Delete Event',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ): Container(),
                              if (widget.showAttendeesButton == true) 
                                const SizedBox(width: 16),
                              if (widget.showAttendeesButton == true)
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: widget.onAttendeesButtonPressed,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: highlightColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16.0),
                                      ),
                                    ),
                                    child: const Text(
                                      'Show Attendees',
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
