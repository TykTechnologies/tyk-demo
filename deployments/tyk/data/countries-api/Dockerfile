FROM node:18-alpine

WORKDIR /app

COPY package.json /app/package.json

# Install all dependencies, including dev dependencies
RUN npm install

# Install nodemon globally
RUN npm install -g nodemon

# We don't copy anything else, as we'll mount the volume in docker-compose
# Create data directory just in case
RUN mkdir -p /app/data

EXPOSE 4100

# Run the app
CMD ["npm", "run", "dev"]
