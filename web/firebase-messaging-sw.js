importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyDPv73xM2mVrMKP91i17yxej6d24tSUbXc",
  authDomain: "golden-care-d4863.firebaseapp.com",
  projectId: "golden-care-d4863",
  storageBucket: "golden-care-d4863.firebasestorage.app",
  messagingSenderId: "143097198020",
  appId: "1:143097198020:web:1bfefba8807c95495b2091",
  measurementId: "G-1E46FR6MEM"
});

const messaging = firebase.messaging();
