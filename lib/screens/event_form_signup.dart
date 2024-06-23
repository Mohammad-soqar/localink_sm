import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:localink_sm/utils/colors.dart';
import 'package:localink_sm/utils/utils.dart';

class EventSignUpForm extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> event;

  const EventSignUpForm({Key? key, required this.event}) : super(key: key);

  @override
  _EventSignUpFormState createState() => _EventSignUpFormState();
}

class _EventSignUpFormState extends State<EventSignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    widget.event['extraFields'].forEach((field) {
      _controllers[field['label']] = TextEditingController();
    });
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _signUpWithForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      var eventDoc = FirebaseFirestore.instance.collection('events').doc(widget.event.id);
      var attendeesCollection = eventDoc.collection('attendees');

      var formData = _controllers.map((label, controller) => MapEntry(label, controller.text));

      await attendeesCollection.doc(userId).set({
        'userId': userId,
        'signedUpAt': FieldValue.serverTimestamp(),
        'formData': formData,
      });

      showSnackBar('You have successfully signed up for the event.', context);
      Navigator.of(context).pop(true); // Returning true to indicate success
    } catch (e) {
      showSnackBar(e.toString(), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fill Form'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              ...widget.event['extraFields'].map<Widget>((field) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field['label']),
                      SizedBox(height: 8.0),
                      TextFormField(
                        controller: _controllers[field['label']],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: field['label'],
                        ),
                        keyboardType: field['type'] == 'number'
                            ? TextInputType.number
                            : TextInputType.text,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter ${field['label']}';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signUpWithForm,
                child: Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
