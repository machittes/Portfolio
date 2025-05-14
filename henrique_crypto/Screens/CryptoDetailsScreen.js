import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ActivityIndicator,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { collection, addDoc } from 'firebase/firestore';
import { db } from '../Firebase/firebaseConfig';
import BackgroundWrapper from '../Components/BackgroundWrapper';

const CryptoDetailsScreen = ({ route }) => {
  const { id } = route.params;
  const [crypto, setCrypto] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchCryptoDetail = async () => {
    try {
      const response = await fetch(`https://api.coinlore.net/api/ticker/?id=${id}`);
      const data = await response.json();
      setCrypto(data[0]);
    } catch (error) {
      console.error('Failed to fetch crypto details:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAddFavorite = async () => {
    try {
      const favoriteRef = collection(db, 'favorites');
      await addDoc(favoriteRef, {
        cryptoID: crypto.id,
        name: crypto.name,
        symbol: crypto.symbol,
        price_usd: crypto.price_usd,
      });
      Alert.alert('Success', `${crypto.name} added to favorites!`);
    } catch (error) {
      Alert.alert('Error', 'Failed to add to favorites.');
    }
  };

  useEffect(() => {
    fetchCryptoDetail();
  }, []);

  if (loading) {
    return (
      <BackgroundWrapper>
        <View style={styles.centered}>
          <ActivityIndicator size="large" color="#007BFF" />
        </View>
      </BackgroundWrapper>
    );
  }

  if (!crypto) {
    return (
      <BackgroundWrapper>
        <View style={styles.centered}>
          <Text>Crypto not found.</Text>
        </View>
      </BackgroundWrapper>
    );
  }

  return (
    <BackgroundWrapper>
      <View style={styles.container}>
        <Text style={styles.title}>{crypto.name} ({crypto.symbol})</Text>
        <Text style={styles.item}>Price: ${crypto.price_usd}</Text>
        <Text style={styles.item}>Rank: {crypto.rank}</Text>
        <Text style={styles.item}>Market Cap: ${crypto.market_cap_usd}</Text>
        <Text style={styles.item}>Supply: {crypto.csupply}</Text>

        <TouchableOpacity style={styles.button} onPress={handleAddFavorite}>
          <Text style={styles.buttonText}>Add to Favorites</Text>
        </TouchableOpacity>
      </View>
    </BackgroundWrapper>
  );
};

export default CryptoDetailsScreen;

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 24,
  },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 26,
    fontWeight: 'bold',
    marginBottom: 16,
  },
  item: {
    fontSize: 16,
    marginBottom: 8,
  },
  button: {
    backgroundColor: '#28a745',
    padding: 16,
    borderRadius: 8,
    marginTop: 24,
    alignItems: 'center',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
});
