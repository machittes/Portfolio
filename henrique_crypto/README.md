# Coin App

A lightweight cryptocurrency tracking app built with **React Native** and **Expo**, using the [CoinLore API](https://www.coinlore.com/cryptocurrency-data-api) for real-time data. The app allows users to explore the top 50 cryptocurrencies, view detailed information, and manage a personalized list of favorites with Firebase integration.

---

## 📱 Features

- ✅ Fetches top 50 cryptocurrencies from CoinLore API
- ✅ Displays name, symbol, price, market cap, and rank
- ✅ Detail screen for individual crypto data
- ✅ Favorite system backed by Firebase Firestore
- ✅ Remove individual or all favorites
- ✅ Beautiful watermark background and consistent UI
- ✅ Built for iOS and Android

---

## 🛠️ Technologies Used

- **React Native (Expo SDK 53)**
- **Firebase Firestore**
- **React Navigation**
- **CoinLore REST API**
- **React Native Vector Icons**
- **Expo modules: gesture-handler, reanimated, safe-area-context**

---

## 📸 Screenshots

| iOS | Android |
|-----|---------|
| ![iOS Home](./screenshots/home_ios.png) | ![Android Home](./screenshots/home_android.png) |
| ![iOS Details](./screenshots/details_ios.png) | ![Android Details](./screenshots/details_android.png) |
| ![iOS Favorites](./screenshots/favorites_ios.png) | ![Android Favorites](./screenshots/favorites_android.png) |

---

## 🚀 Getting Started

### 1. Clone the repository
```bash
git clone https://github.com/your-username/CoinApp.git
cd CoinApp
```

### 2. Install dependencies
```bash
npm install
```

### 3. Run the project
```bash
expo start
```

> Requires Expo Go installed on your device or iOS/Android simulator.

---

## 🌐 API Reference

- [CoinLore API](https://www.coinlore.com/cryptocurrency-data-api)

---

## 📁 Project Structure Highlights

- `App.js` – Root navigator setup
- `/Screens/` – Includes:
  - `HomeScreen` – Top 50 crypto list
  - `CryptoDetailsScreen` – Shows detailed coin info with "Add to Favorites"
  - `FavoritesScreen` – Displays saved favorites with removal options
- `/Firebase/` – Firebase Firestore configuration
- `/Components/` – Shared UI components like the watermark background wrapper

---

## 📚 Learning Outcomes

- Fetching and rendering external API data
- Navigation between screens in a mobile app
- Integrating Firebase Firestore for persistent storage
- Using FlatList, custom styling, and animations in React Native
- Real-world mobile app structure and state management

---

## 📎 References

- CoinLore API: https://www.coinlore.com/cryptocurrency-data-api  
- React Native Docs: https://reactnative.dev/docs/getting-started  
- Firebase Firestore: https://firebase.google.com/docs/firestore  
- React Navigation: https://reactnavigation.org/  
- Expo SDK 53: https://docs.expo.dev/versions/latest/  
- SCRUM Methodology: https://www.scrum.org/resources/what-is-scrum

---

## ⚠️ Disclaimer

This is a personal academic project for portfolio purposes and does not represent financial advice or real-world trading tools.
