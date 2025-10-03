# Flutter Web App Dockerfile
FROM ghcr.io/cirruslabs/flutter:latest AS builder

# Set working directory
WORKDIR /app

# Copy Flutter app files
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get

COPY frontend/lib/ ./lib/
COPY frontend/web/ ./web/
COPY frontend/assets/ ./assets/

# Build web app
RUN flutter build web --release

# Use nginx to serve the web app
FROM nginx:alpine

# Copy built web app
COPY --from=0 /app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY docker/frontend/nginx.conf /etc/nginx/nginx.conf

# Expose port
EXPOSE 3000

# Start nginx
CMD ["nginx", "-g", "daemon off;"]