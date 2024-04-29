FROM python:3.12-slim AS builder

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

# Download repository as a tarball
RUN curl -L https://github.com/TykTechnologies/tyk/archive/refs/heads/master.tar.gz -o tyk.tar.gz && \
    tar -xzvf tyk.tar.gz --strip-components=3 tyk-master/coprocess/proto && \
    rm tyk.tar.gz

# Generate Python bindings from protobuf files
RUN python -m grpc_tools.protoc --proto_path=. --python_out=. --grpc_python_out=. *.proto

FROM python:3.12-slim

WORKDIR /app

# Copy installed dependencies and generated Python bindings from the builder stage
COPY --from=builder /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/
COPY --from=builder /app/requirements.txt .
COPY --from=builder /app/*.py .
COPY --from=builder /app/*.pyi .
COPY --from=builder /app/*.proto .
COPY tyk_async_server.py .

ENV PYTHONUNBUFFERED=1

# Start the application
CMD ["python", "tyk_async_server.py"]
