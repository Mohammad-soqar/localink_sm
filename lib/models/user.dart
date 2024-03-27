import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class User {
  final String email;
  final String uid;
  final String photoUrl;
  final String username;
  final String phonenumber;
  final List followers;
  final List following;
  final DateTime? lastUsernameChangeDate;
  final int emailChangeCount;
  final List<DateTime> emailChangeDates;

  const User({
    required this.username,
    required this.uid,
    required this.photoUrl,
    required this.email,
    required this.phonenumber,
    required this.followers,
    required this.following,
    this.lastUsernameChangeDate,
    this.emailChangeCount = 0,
    this.emailChangeDates = const [],
  });

  static User fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;

    // New logic to parse dates
    DateTime? parseDate(dynamic value) {
      if (value != null) {
        Timestamp timestamp = value as Timestamp;
        return timestamp.toDate();
      }
      return null;
    }

    List<DateTime> parseDateList(List<dynamic> value) {
      return value
          .map((timestamp) => (timestamp as Timestamp).toDate())
          .toList();
    }

    return User(
      username: snapshot['username'],
      uid: snapshot['uid'],
      email: snapshot['email'],
      photoUrl: snapshot['photoUrl'],
      phonenumber: snapshot['phonenumber'],
      followers: List.from(snapshot['followers']),
      following: List.from(snapshot['following']),
      lastUsernameChangeDate: parseDate(snapshot['lastUsernameChangeDate']),
      emailChangeCount: snapshot['emailChangeCount'] ?? 0,
      emailChangeDates: parseDateList(snapshot['emailChangeDates'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    Timestamp? lastUsernameChangeTimestamp = lastUsernameChangeDate != null
        ? Timestamp.fromDate(lastUsernameChangeDate!)
        : null;

    List<Timestamp> emailChangeTimestamps =
        emailChangeDates.map((date) => Timestamp.fromDate(date)).toList();

    return {
      "username": username,
      "uid": uid,
      "email": email,
      "photoUrl": photoUrl,
      "phonenumber": phonenumber,
      "followers": followers,
      "following": following,
      "lastUsernameChangeDate": lastUsernameChangeTimestamp,
      "emailChangeCount": emailChangeCount,
      "emailChangeDates": emailChangeTimestamps,
    };
  }
}
