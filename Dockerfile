# Build Stage
FROM node:18-bullseye as build

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    build-essential \
    udev \
    git \
 && rm -rf /var/lib/apt/lists/*

# Copy package files
COPY package.json yarn.lock ./

# Install dependencies (ignoring scripts to avoid potential native module build issues immediately)
# Then rebuild individually if needed, or just install. 
# Based on previous attempts, standard yarn install works if environment is right.
RUN yarn install --network-timeout 100000

# Copy source code
COPY . .

# Build the application
RUN yarn run build-prod

# Prune dev dependencies to save space (optional but good practice)
RUN yarn install --production --ignore-scripts --prefer-offline

# Production Stage
FROM node:18-bullseye-slim

WORKDIR /app

# Install runtime dependencies (udev is often needed for serial port, though inside docker generic serial might strictly not work without privileges)
RUN apt-get update && apt-get install -y --no-install-recommends \
    udev \
 && rm -rf /var/lib/apt/lists/*

# Copy built assets and necessary files from build stage
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./
COPY --from=build /app/bin ./bin

# Expose port
EXPOSE 8000

# Set environment
ENV NODE_ENV=production

# Start command
CMD ["node", "bin/cncjs"]
