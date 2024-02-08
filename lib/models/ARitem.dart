import 'package:cloud_firestore/cloud_firestore.dart';

enum ItemType { common, rare, epic, legendary }

class ARItem {
  final String id;
  final String name;
  final String description;
  final GeoPoint
      location; // Using Firestore's GeoPoint to store latitude and longitude
  final String modelUrl; // URL to the 3D model file of the item
  final ItemType type; // Enum to represent the rarity of the item

  const ARItem({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.modelUrl,
    required this.type,
  });

  static ARItem fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return ARItem(
      id: snapshot['id'],
      name: snapshot['name'],
      description: snapshot['description'],
      location: snapshot['location'],
      modelUrl: snapshot['modelUrl'],
      type: ItemType.values[snapshot['type']],
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "description": description,
        "location": location,
        "modelUrl": modelUrl,
        "type": type.index,
      };
}
