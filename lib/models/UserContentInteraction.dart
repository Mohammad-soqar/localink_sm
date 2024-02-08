class UserContentInteraction {
  final String userId;
  final List<Interaction> interactions;

  const UserContentInteraction({
    required this.userId,
    required this.interactions,
  });

  Map<String, dynamic> toJson() => {
        "userId": userId,
        "interactions": interactions.map((interaction) => interaction.toJson()).toList(),
      };
}

class Interaction {
  final String contentId;
  final String interactionType;
  final List<String> contentTypes;

  const Interaction({
    required this.contentId,
    required this.interactionType,
    required this.contentTypes,
  });

  Map<String, dynamic> toJson() => {
        "contentId": contentId,
        "interactionType": interactionType,
        "contentTypes": contentTypes,
      };
}
