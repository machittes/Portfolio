import React, { useEffect } from 'react';
import { View, Text, StyleSheet, Alert } from 'react-native';

const BookingScreen = ({ route }) => {
  const { studentId, name, numPeople, room } = route.params;

  const rooms = [
    { roomNumber: 'A101', capacity: 5, available: true },
    { roomNumber: 'A102', capacity: 10, available: false },
    { roomNumber: 'A103', capacity: 8, available: false },
    { roomNumber: 'A104', capacity: 10, available: true },
    { roomNumber: 'A105', capacity: 7, available: true }
  ];

  useEffect(() => {
    const selectedRoom = rooms.find(r => r.roomNumber === room);

    if (!selectedRoom) {
      Alert.alert("Error", "Room not found.");
      return;
    }

    if (!selectedRoom.available) {
      Alert.alert("Unavailable", `${room} is not available right now.`);
    } else if (numPeople > selectedRoom.capacity) {
      Alert.alert("Over capacity", `${room} cannot hold ${numPeople} people.`);
    } else {
      Alert.alert("Success", `Room ${room} is available and booked!`);
    }
  }, []);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Booking Summary</Text>

      <View style={styles.card}>
        <Text style={styles.label}>Student ID:</Text>
        <Text style={styles.value}>{studentId}</Text>
      </View>

      <View style={styles.card}>
        <Text style={styles.label}>Name:</Text>
        <Text style={styles.value}>{name}</Text>
      </View>

      <View style={styles.card}>
        <Text style={styles.label}>People:</Text>
        <Text style={styles.value}>{numPeople}</Text>
      </View>

      <View style={styles.card}>
        <Text style={styles.label}>Room:</Text>
        <Text style={styles.value}>{room}</Text>
      </View>
    </View>
  );
};

export default BookingScreen;

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#EDE7F6',
    padding: 24,
    justifyContent: 'center',
  },
  title: {
    fontSize: 24,
    color: '#512DA8',
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 32,
  },
  card: {
    borderWidth: 1,
    borderColor: '#000',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    backgroundColor: '#FFD600',
  },
  label: {
    fontSize: 16,
    color: '#000',
    fontWeight: '600',
  },
  value: {
    fontSize: 18,
    color: '#000',
    marginTop: 4,
  },
});
