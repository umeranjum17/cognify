# Multi-stage build for production
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
# Install all dependencies (including dev) to build TypeScript
RUN npm ci

# Copy source code
COPY . .

# Build TypeScript
RUN npm run build

# Prune devDependencies to reduce final image size
RUN npm prune --omit=dev

# Production image
FROM node:18-alpine

WORKDIR /app

# Copy built files and production dependencies
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package*.json ./

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Run the server
CMD ["node", "dist/server.js"]

