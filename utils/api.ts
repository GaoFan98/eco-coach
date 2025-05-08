import Constants from 'expo-constants';
import * as dotenv from 'dotenv';

// Load environment variables from .env file if it exists
dotenv.config();

// Use IP address that can be accessed from a mobile device
// For dockerized environments, we use the service names from docker-compose
const API_URL = process.env.API_ENDPOINT || 'http://localhost:3000';
const TILE_SERVER_URL = process.env.TILE_SERVER_URL || 'http://localhost:8080';
const ROUTE_GENERATOR_URL = process.env.ROUTE_GENERATOR_URL || 'http://localhost:5001';

/**
 * Fetch an eco-friendly route between two points
 */
export const fetchRoute = async (startLat, startLon, endLat, endLon) => {
  try {
    const response = await fetch(
      `${API_URL}/api/route?startLat=${startLat}&startLon=${startLon}&endLat=${endLat}&endLon=${endLon}`
    );
    
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Failed to fetch route: ${response.status} ${errorText}`);
    }
    
    return await response.json();
  } catch (error) {
    console.error('Error fetching route:', error);
    throw error;
  }
};

/**
 * Fetch map tile data
 */
export const fetchTile = async (z, x, y) => {
  try {
    const response = await fetch(`${TILE_SERVER_URL}/tiles/${z}/${x}/${y}`);
    
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Failed to fetch tile: ${response.status} ${errorText}`);
    }
    
    return await response.json();
  } catch (error) {
    console.error('Error fetching tile:', error);
    throw error;
  }
};

/**
 * Generate a more complex route with the route-generator service
 */
export const generateRoute = async (startLat, startLon, endLat, endLon) => {
  try {
    const response = await fetch(`${ROUTE_GENERATOR_URL}/api/generate-route`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        startLat,
        startLon,
        endLat,
        endLon
      })
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Failed to generate route: ${response.status} ${errorText}`);
    }
    
    return await response.json();
  } catch (error) {
    console.error('Error generating route:', error);
    throw error;
  }
}; 