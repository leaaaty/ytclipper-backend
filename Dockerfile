FROM node:20-slim

# Install ffmpeg and yt-dlp directly from apt
RUN apt-get update && \
    apt-get install -y ffmpeg yt-dlp && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy dependencies and install
COPY package*.json ./
RUN npm ci --production

# Copy the rest of the app
COPY . .

# Ensure public folder exists
RUN mkdir -p /app/public

# Expose the server port
EXPOSE 3000

# Start the app
CMD ["node", "server.js"]