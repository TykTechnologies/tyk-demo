# Define the base image
FROM python:3.12-slim AS builder

# Set the build argument for the release version
# Example: v5.3.1
#
# Used to fetch the protobuf files for the appropriate Gateway version
ARG GATEWAY_VERSION

# Define working directory
WORKDIR /app

# Install necessary tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    tar \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN pip install --no-cache-dir poetry

# Copy project files
COPY pyproject.toml poetry.lock ./

# Install dependencies
RUN poetry export --dev -f requirements.txt --output requirements.txt && \
    pip install --no-cache-dir -r requirements.txt 

# Download repository as a tarball using the provided release version
RUN curl -L "https://github.com/TykTechnologies/tyk/archive/refs/tags/${GATEWAY_VERSION}.tar.gz" -o tyk.tar.gz && \
    mkdir tyk && \
    tar -xzvf tyk.tar.gz --strip-components=1 -C tyk && \
    mv tyk/coprocess/proto/* . && \
    rm -r tyk tyk.tar.gz

# Generate Python bindings from protobuf files
RUN python -m grpc_tools.protoc --proto_path=. --python_out=. --grpc_python_out=. *.proto

# Define the base image
FROM python:3.12-slim

# Define working directory
WORKDIR /app

# Copy installed dependencies and generated Python bindings from the builder stage
COPY --from=builder /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/
COPY --from=builder /app/requirements.txt .
COPY --from=builder /app/*.py .
COPY --from=builder /app/*.pyi .
COPY --from=builder /app/*.proto .
COPY tyk_async_server.py .

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Start the application
CMD ["python", "tyk_async_server.py"]