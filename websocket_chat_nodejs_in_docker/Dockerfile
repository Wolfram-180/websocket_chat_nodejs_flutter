# Base image
FROM node:16

# Create app directory
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the app code
COPY . .

# Expose the port
EXPOSE 3000

# Run the application
CMD ["node", "app.js"]
