FROM node:22-alpine

# Set working directory
WORKDIR /app

# Install production dependencies
COPY package*.json ./
RUN npm ci --omit=dev || npm install --production

# Copy app sources
COPY . .

# Expose port and run the server
EXPOSE 3000
CMD ["node", "server.js"]
