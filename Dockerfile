# Dockerfile for agahkarakuzu/bids-validator-amd64 and agahkarakuzu/bids-validator-arm64
FROM node:18-alpine

# Install bash and bids-validator
RUN apk add --no-cache bash && npm install -g bids-validator

# Set working directory
WORKDIR /data