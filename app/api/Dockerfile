# Use a small, current LTS base image
FROM node:20-alpine

WORKDIR /usr/src/app

# Install dependencies first (better layer caching)
COPY package*.json ./
RUN npm install --omit=dev

# Copy application source
COPY . .

# Run as non-root for security (defense point)
RUN addgroup -S app && adduser -S app -G app
USER app

EXPOSE 3000
CMD ["npm", "start"]
