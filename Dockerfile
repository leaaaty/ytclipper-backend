FROM node:20-slim

# Install dependencies safely
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ffmpeg \
      python3 \
      python3-pip \
      curl \
      ca-certificates \
      && pip3 install --no-cache-dir -U yt-dlp \
      && apt-get clean && rm -rf /var/lib/apt/lists/*

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