FROM node:18.18-slim

ARG BACKSTAGE_NPM_TOKEN

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential

# Install the create-app package first
RUN npm install -g @backstage/create-app@0.5.18

# Install Backstage using npx
RUN echo "backstage" | npx @backstage/create-app@0.5.18

# Set the auth token needed to access the entity provider NPM package
# WARNING: this embeds the NPM access token into the image - be aware of this before you distribute
RUN npm config set //registry.npmjs.org/:_authToken $BACKSTAGE_NPM_TOKEN

# set the working directory to the Backstage root directory
WORKDIR /backstage

# Install Tyk entity provider plugin
RUN yarn --cwd packages/backend add @tyk-technologies/plugin-catalog-backend-module-tyk

# Copy amended backend plugin source, that initialises the Tyk Entity Provider plugin
COPY data/backstage/packages/backend/src/index.ts /backstage/packages/backend/src/index.ts

# Start both Backstage back and front ends
CMD ["yarn", "dev"]