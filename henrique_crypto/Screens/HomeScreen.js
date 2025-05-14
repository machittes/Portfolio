import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import BackgroundWrapper from '../Components/BackgroundWrapper';

const HomeScreen = ({ navigation }) => {
  const [cryptos, setCryptos] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchCryptos = async () => {
    try {
      const response = await fetch('https://api.coinlore.net/api/tickers/?start=0&limit=50');
      const data = await response.json();
      setCryptos(data.data); // "data" key holds the array
    } catch (error) {
      console.error('Failed to fetch cryptos:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCryptos();
  }, []);

  const renderItem = ({ item }) => (
    <TouchableOpacity
      style={styles.card}
      onPress={() => navigation.navigate('Crypto Details', { id: item.id })}
    >
      <Text style={styles.name}>{item.name}</Text>
      <Text style={styles.symbol}>{item.symbol}</Text>
      <Text style={styles.price}>${item.price_usd}</Text>
    </TouchableOpacity>
  );

  return (
    <BackgroundWrapper>
      <View style={styles.container}>
        <Text style={styles.header}>Top 50 Cryptos</Text>
        <Text style={styles.subheader}>by CoinLore API</Text>

        <TouchableOpacity
          style={styles.exchangeButton}
          onPress={() => navigation.navigate("My Exchange")}
        >
          <Text style={styles.exchangeButtonText}>MY EXCHANGE</Text>
        </TouchableOpacity>

        {loading ? (
          <ActivityIndicator size="large" color="#007BFF" />
        ) : (
          <FlatList
            data={cryptos}
            keyExtractor={(item) => item.id.toString()}
            renderItem={renderItem}
            contentContainerStyle={{ paddingBottom: 16 }}
          />
        )}
      </View>
    </BackgroundWrapper>
  );
};

export default HomeScreen;


const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingTop: 60,
    paddingHorizontal: 16,

  },
  header: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
    alignSelf: 'center',
  },
  card: {
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 16,
    marginBottom: 12,
    elevation: 3,
  },
  name: {
    fontSize: 18,
    fontWeight: 'bold',
  },
  symbol: {
    fontSize: 14,
    color: 'gray',
  },
  price: {
    marginTop: 8,
    fontSize: 16,
    color: '#007BFF',
  },

  exchangeButton: {
    backgroundColor: "#28a745",
    padding: 12,
    borderRadius: 8,
    alignItems: "center",
    marginBottom: 16,
  },
  exchangeButtonText: {
    color: "#fff",
    fontWeight: "bold",
    fontSize: 16,
  },
  
  subheader: {
    fontSize: 12,
    color: 'gray',
    textAlign: 'right',
    marginBottom: 10,
  },
  

});
