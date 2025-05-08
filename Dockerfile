FROM node:18-alpine

WORKDIR /app

# Install global expo-cli
RUN npm install -g expo-cli

# Copy package.json and package-lock.json
COPY package.json package-lock.json* ./

# Install dependencies with legacy-peer-deps flag
RUN npm install --legacy-peer-deps

# Copy the rest of the app
COPY . .

# Expose the port Expo runs on
EXPOSE 19000
EXPOSE 19001
EXPOSE 19002

# Default command - will be overridden by docker-compose
CMD ["npm", "start"] 