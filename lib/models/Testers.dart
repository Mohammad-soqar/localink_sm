class Tester {
  final String name;
  final String email;
  final String phoneNumber;

  Tester({required this.name, required this.email, required this.phoneNumber});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
    };
  }

  factory Tester.fromMap(Map<String, dynamic> map) {
    return Tester(
      name: map['name'],
      email: map['email'],
      phoneNumber: map['phoneNumber'],
    );
  }
}
