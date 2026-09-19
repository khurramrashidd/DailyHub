// Replace with your real Firebase config values
const firebaseConfig = {
  apiKey: "AIzaSyCf_RlgHv5X7ie7xa9rQJE6NNkiCqJmtI0",
  authDomain: "khurram-world.firebaseapp.com",
  databaseURL: "https://khurram-world-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "khurram-world",
  storageBucket: "khurram-world.firebasestorage.app",
  messagingSenderId: "217678871138",
  appId: "1:217678871138:web:f4787814bfe80059d4af3b",
  measurementId: "G-RPDMNN90K8"
};
firebase.initializeApp(firebaseConfig);
const database = firebase.database();
const auth = firebase.auth();
const googleProvider = new firebase.auth.GoogleAuthProvider();

// Global refs
let currentUserUid = null;
let currentWorkspaceUid = null; // Tracks whose dashboard you are viewing
let currentWorkspaceRole = 'owner'; // 'owner', 'view', 'add', 'master'

let profileRef = null;
let tripsRef = null;
let todosRef = null;