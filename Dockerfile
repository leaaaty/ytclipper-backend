# Stage 1: build Node dependencies
FROM node:20-slim AS builder

WORKDIR /app

# Copy only package files for caching
COPY package*.json ./

# Install production dependencies
RUN npm ci --production

# Stage 2: final image
FROM node:20-slim

WORKDIR /app

# Install system dependencies: ffmpeg, Python3, pip, curl, certificates
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ffmpeg \
      python3-full \
      python3-pip \
      curl \
      ca-certificates \
    && pip3 install --no-cache-dir -U yt-dlp \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Node dependencies from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy the rest of the app
COPY . .

# Ensure public folder exists
RUN mkdir -p /app/public

# Expose server port
EXPOSE 3000

# Start the Node server
CMD ["node", "server.js"]