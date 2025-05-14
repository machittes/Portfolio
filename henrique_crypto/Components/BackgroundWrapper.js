import React from 'react';
import { ImageBackground, StyleSheet } from 'react-native';

const BackgroundWrapper = ({ children }) => {
  return (
    <ImageBackground
      source={require('../assets/background/watermark.png')}
      style={styles.background}
      resizeMode="repeat"
      imageStyle={styles.image}
    >
      {children}
    </ImageBackground>
  );
};

const styles = StyleSheet.create({
  background: {
    flex: 1,
  },
  image: {
    opacity: 0.06,
    transform: [{ rotate: '45deg' }],
  },
});

export default BackgroundWrapper;
