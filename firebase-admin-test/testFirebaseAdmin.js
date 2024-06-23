const admin = require('firebase-admin');
const serviceAccount = require(
    './localink-778c5-firebase-adminsdk-esl97-30f9df7c1b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://localink-778c5.firebaseio.com' 
});

console.log('Firebase Admin SDK initialized successfully');


admin.firestore().collection('testCollection').get()
    .then(snapshot => {
        console.log('Successfully connected to Firestore, found', snapshot.size, 'documents.');
        process.exit(0);
    })
    .catch(error => {
        console.error('Error connecting to Firestore:', error);
        process.exit(1);
    });
