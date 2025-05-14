import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import HomeScreen from '../Screens/HomeScreen';
import CryptoDetailsScreen from '../Screens/CryptoDetailsScreen';
import FavoritesScreen from '../Screens/FavoritesScreen';

const Stack = createNativeStackNavigator();

export default function StackNavigator() {
  return (
    <Stack.Navigator>
      <Stack.Screen name="Top Cryptos" component={HomeScreen} />
      <Stack.Screen name="Crypto Details" component={CryptoDetailsScreen} />
      <Stack.Screen name="My Exchange" component={FavoritesScreen} />
    </Stack.Navigator>
  );
}
