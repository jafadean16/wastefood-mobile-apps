importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAMRoGNQl-0ij0Lahy6xLh-sgBMLtK7iTk",
  authDomain: "wastefood-dfcf5.firebaseapp.com",
  projectId: "wastefood-dfcf5",
  storageBucket: "wastefood-dfcf5.appspot.com",
  messagingSenderId: "700741537981",
  appId: "1:700741537981:web:a7ec68a7b8cf85da6427d4"
});

const messaging = firebase.messaging();
