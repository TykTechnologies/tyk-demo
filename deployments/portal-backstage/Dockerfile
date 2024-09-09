FROM node:20-slim

ARG NPM_ACCESS_TOKEN

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential

RUN npm install -g @backstage/create-app@0.5.18

# Install Backstage using npx
RUN echo "backstage" | npx @backstage/create-app@0.5.18 --skip-install

RUN cd backstage && yarn install

RUN npm config set //registry.npmjs.org/:_authToken $NPM_ACCESS_TOKEN

# RUN yarn --cwd packages/backend add @tyk-technologies/plugin-catalog-backend-module-tyk


# # From here on we use the least-privileged `node` user to run the backend.

WORKDIR /backstage

# # Install Backstage plugins
# WORKDIR /backstage-app
# RUN npm install @backstage/plugin-user-settings \
#                 @backstage/plugin-catalog \
#                 @backstage/plugin-api-docs

# # Build the Backstage app
# RUN npm run build

USER node

# Start the Backstage app
CMD ["yarn", "dev"]