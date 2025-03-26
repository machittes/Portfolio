# henrique_a1 – Room Booking App

This is a simple multi-screen mobile application built with **React Native (Expo)** for booking study rooms on campus. It was developed as part of an academic assignment.

## 🧩 Features

- **Sign In Screen**
  - Username: `admin`
  - Password: `admin`
  - Validates credentials and navigates to dashboard.

- **Dashboard Screen**
  - Allows users to enter:
    - Student ID
    - Name
    - Number of people
    - Room selection from predefined list (A101–A105)
  - Includes a "Check Availability" button.
  - Logout button navigates back to Sign In.

- **Booking Screen**
  - Validates if selected room is available and has enough capacity.
  - Displays alerts based on room status (Available / Unavailable / Over Capacity).
  - Shows a booking summary.

## 🎨 Tech Stack

- React Native (Expo)
- React Navigation (Native Stack)
- JavaScript (function components, `let` and `const`)
- Custom styling (yellow & purple theme)

## 🔧 How to Run

```bash
npm install
npx expo start
```

Make sure you have an Android or iOS emulator running, or use Expo Go to scan the QR code.

## 💡 Notes

- The project follows all technical requirements of the assignment.
- The room data is hardcoded on the Booking screen.
- No Firebase or backend connection – this is a standalone local app.