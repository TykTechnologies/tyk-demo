FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

# Install all dependencies, including dev dependencies
RUN npm install

# We don't copy anything else, as we'll mount the volume in docker-compose
# Create data directory just in case
RUN mkdir -p /app/data

EXPOSE 4100

# Default command will be overridden by docker-compose
CMD ["npm", "run", "dev"]
