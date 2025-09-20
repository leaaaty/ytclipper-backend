# Stage 1: build dependencies (Node modules)
FROM node:20-slim AS builder

WORKDIR /app

# Copy only package files for efficient caching
COPY package*.json ./

# Install production dependencies
RUN npm ci --production

# Stage 2: final image
FROM node:20-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ffmpeg \
      curl \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download standalone yt-dlp binary
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp \
    && chmod +x /usr/local/bin/yt-dlp

# Copy Node dependencies from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy the rest of the app
COPY . .

# Ensure public folder exists
RUN mkdir -p /app/public

# Expose server port
EXPOSE 3000

# Start the app
CMD ["node", "server.js"]