/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

admin.initializeApp();

exports.sendNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const notification = snap.data();
      const { userId, title, body, data, fcmTokens } = notification;

      if (!fcmTokens || fcmTokens.length === 0) {
        console.log('No FCM tokens found for user:', userId);
        return null;
      }

      const message = {
        notification: {
          title: title,
          body: body,
        },
        data: data,
        tokens: fcmTokens,
      };

      console.log('Sending FCM message:', message);

      const response = await admin.messaging().sendMulticast(message);
      console.log('Successfully sent message:', response);

      return null;
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });
