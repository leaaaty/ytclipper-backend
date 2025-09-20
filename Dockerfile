# Stage 1: build Node dependencies
FROM node:20-slim AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --production

# Stage 2: final image
FROM node:20-slim

WORKDIR /app

# Install system dependencies: ffmpeg, curl, certificates
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ffmpeg \
      curl \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download standalone yt-dlp binary (no Python needed)
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp \
    && chmod +x /usr/local/bin/yt-dlp

# Copy Node modules from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy the rest of the app
COPY . .

# Ensure public folder exists
RUN mkdir -p /app/public

# Expose port
EXPOSE 3000

# Start server
CMD ["node", "server.js"]