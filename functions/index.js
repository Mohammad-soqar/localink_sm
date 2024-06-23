const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {LanguageServiceClient} = require("@google-cloud/language");
const {ImageAnnotatorClient} = require("@google-cloud/vision");
const cloudinary = require("cloudinary").v2;
const serviceAccount = require(
    "./localink-778c5-firebase-adminsdk-esl97-30f9df7c1b.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://localink-778c5-default-rtdb.europe-west1.firebasedatabase.app/",
});

const languageClient = new LanguageServiceClient();
const visionClient = new ImageAnnotatorClient();

const offensiveWords = [
  "fuck", "shit", "bitch", "asshole", "bastard", "dick", "pussy", "cunt",
  "israel", "jews",
];

cloudinary.config({
  cloud_name: functions.config().cloudinary.cloud_name,
  api_key: functions.config().cloudinary.api_key,
  api_secret: functions.config().cloudinary.api_secret,
});

console.log("Cloudinary config loaded.");

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

  if (containsOffensiveLanguage(description)) {
    return {
      approved: false,
      reason: "Inappropriate language detected",
    };
  }

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

/**
 * Transcodes video using Cloudinary.
 * @param {Object} snap - Firestore document snapshot.
 * @param {Object} context - The function context.
 */
exports.transcodeVideo = functions.firestore
    .document("posts/{postId}/postMedia/{mediaId}")
    .onCreate(async (snap, context) => {
      const mediaData = snap.data();
      const mediaUrl = mediaData.mediaUrl;

      console.log("Starting video transcoding for:", mediaUrl);

      try {
        const result = await cloudinary.uploader.upload(mediaUrl, {
          resource_type: "video",
          eager: [
            {width: 720, height: 1280, crop: "fill"}, // 9:16 aspect ratio
          ],
        });

        console.log("Video transcoding completed:", result);

        await snap.ref.update({
          transcodedUrl: result.eager[0].secure_url,
        });

        console.log("Transcoded URL updated in Firestore");
      } catch (error) {
        console.error("Error during video transcoding:", error);
      }
    });

/**
 * Preprocesses media URLs for posts.
 * @param {Object} snap - Firestore document snapshot.
 * @param {Object} context - The function context.
 */
exports.preprocessMediaUrls = functions.firestore
    .document("posts/{postId}")
    .onCreate(async (snap, context) => {
      const postId = context.params.postId;

      const mediaSnapshot = await admin.firestore()
          .collection("posts")
          .doc(postId)
          .collection("postMedia")
          .get();

      const mediaUrls = mediaSnapshot.docs.map((doc) => doc.data().mediaUrl);

      await admin.firestore()
          .collection("posts")
          .doc(postId)
          .update({mediaUrls});

      console.log(`Preprocessed media URLs for post ${postId}`);
    });

/**
 * Sends a notification and saves it to Firestore.
 * @param {Array<string>} tokens - The recipient tokens.
 * @param {string} title - The notification title.
 * @param {string} body - The notification body.
 * @param {Object} data - Additional data.
 * @param {string} userId - The user ID.
 */
const sendNotification = (tokens, title, body, data, userId) => {
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: data,
    tokens: tokens,
  };

  admin.messaging().sendMulticast(message)
      .then((response) => {
        console.log("Successfully sent message:", response);

        // Save notification to Firestore
        const notificationData = {
          title: title,
          body: body,
          data: data,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        };
        admin.firestore().collection("users")
            .doc(userId).collection("notifications").add(notificationData);
      })
      .catch((error) => {
        console.error("Error sending message:", error);
      });
};

/**
 * Example function to send an event update notification.
 * @param {string} userId - The user ID.
 * @param {string} eventId - The event ID.
 * @param {string} eventName - The event name.
 */
const sendEventUpdate = async (userId, eventId, eventName) => {
  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  const userData = userDoc.data();
  const tokens = userData.tokens || [];

  sendNotification(tokens,
      "Event Update",
      `There's an update for the event: ${eventName}`,
      {type: "event_update", eventId: eventId},
      userId);
};

/**
 * Sends a new follower notification.
 * @param {string} userId - The user ID.
 * @param {string} followerId - The follower ID.
 * @param {string} followerName - The follower name.
 */
const sendNFollowerNotification = async (userId, followerId, followerName) => {
  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  const userData = userDoc.data();
  const tokens = userData.tokens || [];

  sendNotification(tokens,
      "New Follower",
      `${followerName} started following you`, {
        type: "new_follower",
        followerId: followerId,
      }, userId);
};

/**
 * Sends a like notification.
 * @param {string} userId - The user ID.
 * @param {string} postId - The post ID.
 * @param {string} likerId - The liker ID.
 * @param {string} likerName - The liker name.
 */
const sendLikeNotification = async (userId, postId, likerId, likerName) => {
  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  const userData = userDoc.data();
  const tokens = userData.tokens || [];

  sendNotification(tokens,
      "New Like",
      `${likerName} liked your post`, {
        type: "like",
        postId: postId,
        likerId: likerId,
      }, userId);
};

/**
 * Sends a comment notification.
 * @param {string} userId - The user ID.
 * @param {string} postId - The post ID.
 * @param {string} commenterId - The commenter ID.
 * @param {string} commenterName - The commenter name.
 */
const sendCommentNotification = async (
    userId, postId, commenterId, commenterName) => {
  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  const userData = userDoc.data();
  const tokens = userData.tokens || [];

  sendNotification(tokens,
      "New Comment",
      `${commenterName} commented on your post`, {
        type: "comment",
        postId: postId,
        commenterId: commenterId,
      }, userId);
};

/**
 * Sends a system update notification.
 * @param {string} userId - The user ID.
 * @param {string} updateMessage - The update message.
 */
const sendSystemUpdate = async (userId, updateMessage) => {
  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  const userData = userDoc.data();
  const tokens = userData.tokens || [];

  sendNotification(tokens,
      "System Update",
      updateMessage, {
        type: "system_update",
      }, userId);
};

/**
 * Sends a promotional offer notification.
 * @param {string} userId - The user ID.
 * @param {string} offerId - The offer ID.
 * @param {string} offerDetails - The offer details.
 */
const sendPromotionalOffer = async (userId, offerId, offerDetails) => {
  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  const userData = userDoc.data();
  const tokens = userData.tokens || [];

  sendNotification(tokens,
      "Special Offer",
      offerDetails, {
        type: "promotional_offer",
        offerId: offerId,
      }, userId);
};

/**
 * Sends a message notification.
 * @param {string} userId - The user ID.
 * @param {string} messageSenderId - The message sender ID.
 * @param {string} messageSenderName - The message sender name.
 * @param {string} messageText - The message text.
 */
const sendMessageNotification = async (
    userId, messageSenderId, messageSenderName, messageText) => {
  const userDoc =
   await admin.firestore().collection("users").doc(userId).get();
  const userData = userDoc.data();
  const tokens = userData.tokens || [];

  sendNotification(tokens,
      "New Message",
      `${messageSenderName}: ${messageText}`, {
        type: "new_message",
        senderId: messageSenderId,
      }, userId);
};

exports.sendMessageNotification = functions.https.onCall(
    async (data, context) => {
      const {userId, messageSenderId, messageSenderName, messageText} = data;
      return sendMessageNotification(
          userId, messageSenderId, messageSenderName, messageText);
    });

exports.sendNFollowerNotification = functions.https.onCall(
    async (data, context) => {
      const {userId, followerId, followerName} = data;
      return sendNFollowerNotification(userId, followerId, followerName);
    });

exports.sendEventUpdate = functions.https.onCall(async (data, context) => {
  const {userId, eventId, eventName} = data;
  return sendEventUpdate(userId, eventId, eventName);
});

exports.sendLikeNotification = functions.https.onCall(async (data, context) => {
  const {userId, postId, likerId, likerName} = data;
  return sendLikeNotification(userId, postId, likerId, likerName);
});

exports.sendCommentNotification = functions.https.onCall(
    async (data, context) => {
      const {userId, postId, commenterId, commenterName} = data;
      return sendCommentNotification(
          userId, postId, commenterId, commenterName);
    });

exports.sendSystemUpdate = functions.https.onCall(async (data, context) => {
  const {userId, updateMessage} = data;
  return sendSystemUpdate(userId, updateMessage);
});

exports.sendPromotionalOffer = functions.https.onCall(async (data, context) => {
  const {userId, offerId, offerDetails} = data;
  return sendPromotionalOffer(userId, offerId, offerDetails);
});
