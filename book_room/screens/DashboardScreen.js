import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  StyleSheet,
  Alert,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
  TouchableOpacity
} from 'react-native';
import { Picker } from '@react-native-picker/picker';

const DashboardScreen = ({ navigation }) => {
  const [studentId, setStudentId] = useState('');
  const [name, setName] = useState('');
  const [numPeople, setNumPeople] = useState('');
  const [room, setRoom] = useState('A101');

  const handleLogout = () => {
    navigation.navigate('SignIn');
  };

  const handleCheckAvailability = () => {
    if (!studentId || !name || !numPeople) {
      Alert.alert('Missing Information', 'Please fill all fields.');
      return;
    }

    navigation.navigate('Booking', {
      studentId,
      name,
      numPeople: parseInt(numPeople),
      room,
    });
  };

  return (
    <KeyboardAvoidingView
      style={{ flex: 1 }}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView contentContainerStyle={styles.container}>
        <View style={styles.logoutContainer}>
          <TouchableOpacity style={styles.buttonSmall} onPress={handleLogout}>
            <Text style={styles.buttonText}>Logout</Text>
          </TouchableOpacity>
        </View>

        <Text style={styles.title}>Book a Room</Text>

        <Text style={styles.label}>Student ID</Text>
        <TextInput style={styles.input} value={studentId} onChangeText={setStudentId} />

        <Text style={styles.label}>Name</Text>
        <TextInput style={styles.input} value={name} onChangeText={setName} />

        <Text style={styles.label}>Number of People</Text>
        <TextInput
          style={styles.input}
          value={numPeople}
          onChangeText={setNumPeople}
          keyboardType="numeric"
        />

        <Text style={styles.label}>Select Room</Text>
        <Picker selectedValue={room} onValueChange={setRoom} style={styles.input}>
          <Picker.Item label="A101" value="A101" />
          <Picker.Item label="A102" value="A102" />
          <Picker.Item label="A103" value="A103" />
          <Picker.Item label="A104" value="A104" />
          <Picker.Item label="A105" value="A105" />
        </Picker>

        <View style={styles.centeredButton}>
          <TouchableOpacity style={styles.button} onPress={handleCheckAvailability}>
            <Text style={styles.buttonText}>Check Availability</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
};

export default DashboardScreen;

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    padding: 24,
    backgroundColor: '#F2E9FF',
  },
  logoutContainer: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#4B0082',
    textAlign: 'center',
    marginBottom: 24,
  },
  label: {
    fontSize: 16,
    marginTop: 12,
    color: '#000',
  },
  input: {
    borderWidth: 1,
    borderRadius: 6,
    padding: 10,
    marginTop: 4,
    borderColor: '#000',
    backgroundColor: '#FFFFE0',
  },
  button: {
    backgroundColor: '#FFD700',
    paddingVertical: 12,
    paddingHorizontal: 24,
    borderRadius: 8,
    alignItems: 'center',
  },
  buttonSmall: {
    backgroundColor: '#FFD700',
    paddingVertical: 6,
    paddingHorizontal: 16,
    borderRadius: 8,
  },
  buttonText: {
    color: '#4B0082',
    fontSize: 16,
    fontWeight: 'bold',
  },
  centeredButton: {
    alignItems: 'center',
    marginTop: 20,
  },
});
