const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {LanguageServiceClient} = require("@google-cloud/language");
const {ImageAnnotatorClient} = require("@google-cloud/vision");

admin.initializeApp();

const languageClient = new LanguageServiceClient();
const visionClient = new ImageAnnotatorClient();

// List of offensive words/phrases for explicit check
const offensiveWords = [
  "fuck", "shit", "bitch", "asshole", "bastard", "dick", "pussy", "cunt",
];

/**
 * Checks if the text contains offensive language.
 * @param {string} text - The text to check.
 * @return {boolean} - True if offensive language is found, otherwise false.
 */
function containsOffensiveLanguage(text) {
  const lowercasedText = text.toLowerCase();
  for (const word of offensiveWords) {
    if (lowercasedText.includes(word)) {
      return true;
    }
  }
  return false;
}

/**
 * Scheduled function to delete events older than 10 days.
 * @param {Object} context - The function context.
 */
exports.scheduledFunction = functions.pubsub.schedule("every 24 hours")
    .onRun(async (context) => {
      const now = admin.firestore.Timestamp.now();
      const tenDaysAgo = new admin.firestore.Timestamp(
          now.seconds - 10 * 24 * 60 * 60, now.nanoseconds,
      );

      const eventsSnap = await admin.firestore().collection("events").get();
      const batch = admin.firestore().batch();

      for (const eventDoc of eventsSnap.docs) {
        const deletedEventsSnap = await eventDoc.ref
            .collection("deleted_events")
            .where("deletedAt", "<=", tenDaysAgo)
            .get();

        deletedEventsSnap.forEach((doc) => {
          batch.delete(doc.ref);
        });
      }

      await batch.commit();
      console.log("Successfully deleted events older than 10 days.");
    });

/**
 * Verifies event content for appropriateness.
 * @param {Object} data - The event data.
 * @param {Object} context - The function context.
 * @return {Object} - The verification result.
 */
exports.verifyEventContent = functions.https.onCall(async (data, context) => {
  const {description, imageUrls} = data;

  console.log("Received description:", description);
  console.log("Received imageUrls:", imageUrls);

  // Explicit profanity check
  if (containsOffensiveLanguage(description)) {
    return {
      approved: false,
      reason: "Inappropriate language detected",
    };
  }

  // Analyze sentiment
  const document = {
    content: description,
    type: "PLAIN_TEXT",
  };

  try {
    const [sentimentResult] = await languageClient.analyzeSentiment({document});
    const sentiment = sentimentResult.documentSentiment;

    console.log("Sentiment score:", sentiment.score);
    console.log("Sentiment magnitude:", sentiment.magnitude);

    if (sentiment.score < 0) {
      return {
        approved: false,
        reason: "Negative sentiment detected",
      };
    }

    // Check images for inappropriate content
    for (const imageUrl of imageUrls) {
      const [result] = await visionClient.safeSearchDetection(imageUrl);
      const detections = result.safeSearchAnnotation;

      console.log("SafeSearch results for image:", imageUrl);
      console.log("Adult content:", detections.adult);
      console.log("Violence content:", detections.violence);

      if (detections.adult === "LIKELY" ||
          detections.adult === "VERY_LIKELY" ||
          detections.violence === "LIKELY" ||
          detections.violence === "VERY_LIKELY") {
        return {
          approved: false,
          reason: "Inappropriate image content detected",
        };
      }
    }

    return {approved: true};
  } catch (error) {
    console.error("Error analyzing event content:", error);
    throw new functions.https.HttpsError("internal",
        "Error analyzing event content", error);
  }
});
