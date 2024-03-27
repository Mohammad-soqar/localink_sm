import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:localink_sm/models/Testers.dart';

class AddTesterPage extends StatefulWidget {
  @override
  _AddTesterPageState createState() => _AddTesterPageState();
}

class _AddTesterPageState extends State<AddTesterPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _phoneNumber = '';

  Future<void> _addTester() async {
    final tester = Tester(name: _name, email: _email, phoneNumber: _phoneNumber);
    await FirebaseFirestore.instance.collection('testers').add(tester.toMap());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Tester')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              decoration: InputDecoration(labelText: 'Name'),
              validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
              onChanged: (value) => setState(() => _name = value),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Email'),
              validator: (value) => value!.isEmpty ? 'Please enter an email' : null,
              onChanged: (value) => setState(() => _email = value),
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Phone Number'),
              validator: (value) => value!.isEmpty ? 'Please enter a phone number' : null,
              onChanged: (value) => setState(() => _phoneNumber = value),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _addTester();
                  Navigator.pop(context);
                }
              },
              child: Text('Add Tester'),
            ),
          ],
        ),
      ),
    );
  }
}
