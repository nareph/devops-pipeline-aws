# syntax=docker/dockerfile:1

FROM rust:alpine AS builder

WORKDIR /devops-pipeline-api

# Step 1: Copy only manifest files first
# This leverages Docker layer caching - dependencies won't rebuild unless Cargo.toml changes
COPY Cargo.toml Cargo.lock ./

# Step 2: Create a dummy main.rs to compile dependencies
# This trick allows us to cache dependency compilation separately from source code
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# Step 3: Copy the actual source code
# Now that dependencies are cached, only the application code will be compiled
COPY src ./src/

# Step 4: Touch main.rs to force recompilation of the final binary
# This ensures the real binary is built with our actual source code
RUN touch src/main.rs && cargo build --release

FROM alpine:3.21 AS runtime

LABEL org.opencontainers.image.source=https://github.com/nareph/devops-pipeline-aws
LABEL org.opencontainers.image.description="devops-pipeline-api"
LABEL org.opencontainers.image.licenses=MIT

# Build argument for port with default value 8080
# This can be overridden at build time with: --build-arg PORT_ARG=3000
ARG PORT_ARG=8080

# Environment variable for runtime, falls back to ARG value
# This can be overridden at runtime with: -e PORT=3000
ENV PORT=${PORT_ARG}

# Document which port the application uses
# Note: This is informational only - actual port mapping is done with -p flag
EXPOSE ${PORT}

# Copy the compiled binary from builder stage
COPY --from=builder /devops-pipeline-api/target/release/devops-pipeline-api /bin/devops-pipeline-api

# Create a non-root user for security best practices
# Running as non-root limits potential damage if the application is compromised
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Run the application
CMD ["/bin/devops-pipeline-api"]
