// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyBDPUc9YbX0woM_ZIUCUfkTLEXGvR6wlaU",
  authDomain: "myfirstproject-d687a.firebaseapp.com",
  projectId: "myfirstproject-d687a",
  storageBucket: "myfirstproject-d687a.firebasestorage.app",
  messagingSenderId: "824798157872",
  appId: "1:824798157872:web:5e33f597f770efb968a1f5"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
// Export Firestore
const db = getFirestore(app);

export { db };