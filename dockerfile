FROM node:20-slim

RUN apt-get update && \
    apt-get install -y ffmpeg python3 python3-pip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install -U yt-dlp

WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .

RUN mkdir -p /app/public

EXPOSE 3000
CMD ["node", "server.js"]
