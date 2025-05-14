import React, { useEffect, useState } from 'react';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { getFirestore, collection, getDocs, deleteDoc, doc } from 'firebase/firestore';
import { useNavigation } from '@react-navigation/native';
import { db } from '../Firebase/firebaseConfig';
import BackgroundWrapper from '../Components/BackgroundWrapper';

const FavoritesScreen = () => {
  const [favorites, setFavorites] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigation = useNavigation();

  const fetchFavorites = async () => {
    try {
      const snapshot = await getDocs(collection(db, 'favorites'));
      const list = snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));
      setFavorites(list);
    } catch (error) {
      console.error('Failed to fetch favorites:', error);
    } finally {
      setLoading(false);
    }
  };

  const clearFavorites = async () => {
    try {
      const snapshot = await getDocs(collection(db, 'favorites'));
      const batchDeletes = snapshot.docs.map((docSnap) =>
        deleteDoc(doc(db, 'favorites', docSnap.id))
      );
      await Promise.all(batchDeletes);
      setFavorites([]);
    } catch (error) {
      console.error('Error clearing favorites:', error);
    }
  };

  const removeOne = async (id) => {
    try {
      await deleteDoc(doc(db, 'favorites', id));
      setFavorites((prev) => prev.filter((item) => item.id !== id));
    } catch (error) {
      console.error('Error removing item:', error);
    }
  };

  useEffect(() => {
    fetchFavorites();
  }, []);

  const renderItem = ({ item }) => (
    <TouchableOpacity
      onPress={() => navigation.navigate('Crypto Details', { id: item.cryptoID.toString() })}
    >
      <View style={styles.card}>
        <View style={styles.row}>
          <View>
            <Text style={styles.name}>{item.name} ({item.symbol})</Text>
            <Text style={styles.price}>${item.price_usd}</Text>
          </View>
          <TouchableOpacity onPress={() => removeOne(item.id)}>
            <Icon name="trash-can-outline" size={24} color="#ff4444" />
          </TouchableOpacity>
        </View>
      </View>
    </TouchableOpacity>
  );

  return (
    <BackgroundWrapper>
      <View style={styles.container}>
        {favorites.length === 0 ? (
          <Text style={styles.empty}>No currency found</Text>
        ) : (
          <FlatList
            data={favorites}
            keyExtractor={(item) => item.id}
            renderItem={renderItem}
          />
        )}

        <TouchableOpacity
          style={[
            styles.button,
            favorites.length === 0 && { backgroundColor: '#ccc' },
          ]}
          onPress={clearFavorites}
          disabled={favorites.length === 0}
        >
          <Text style={styles.buttonText}>CLEAR ALL CRYPTOS</Text>
        </TouchableOpacity>
      </View>
    </BackgroundWrapper>
  );
};

export default FavoritesScreen;


const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
  },
  card: {
    padding: 16,
    marginBottom: 12,
    backgroundColor: '#f2f2f2',
    borderRadius: 8,
  },
  name: {
    fontSize: 18,
    fontWeight: 'bold',
  },
  price: {
    fontSize: 16,
    marginTop: 4,
  },
  remove: {
    color: '#ff4444',
    marginTop: 8,
  },
  button: {
    backgroundColor: '#28a745',
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 16,
  },
  buttonText: {
    color: '#fff',
    fontWeight: 'bold',
  },
  empty: {
    fontSize: 18,
    textAlign: 'center',
    marginTop: 32,
    color: 'gray',
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
});
