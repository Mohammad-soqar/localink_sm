
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final databaseReference = FirebaseDatabase.instance.ref();

    return Scaffold(
      appBar: AppBar(
        title: Text("User Online Status"),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: databaseReference.child('status').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return Center(child: Text("No data available"));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          Map<dynamic, dynamic> statusMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          return ListView(
            children: statusMap.entries.map((entry) {
              return ListTile(
                title: Text("User: ${entry.key}"),
                trailing: Text(entry.value['online'] ? 'Online' : 'Offline'),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}