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

# set the working directory to the Backstage root directory
WORKDIR /backstage

# Set the auth token needed to access the entity provider NPM package, install Tyk entity provider plugin, then delete the npm config to not leave the token in the image
RUN echo "//registry.npmjs.org/:_authToken=${BACKSTAGE_NPM_TOKEN}" > .npmrc && \
    yarn --cwd packages/backend add @tyk-technologies/plugin-catalog-backend-module-tyk && \
    rm .npmrc

# Copy amended backend plugin source, which includes initialisation for the Tyk Entity Provider plugin
COPY data/backstage/packages/backend/src/index.ts /backstage/packages/backend/src/index.ts

# Start both Backstage back and front ends
CMD ["yarn", "dev"]