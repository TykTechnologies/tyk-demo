# Use official Python 3 slim image
FROM python:3.11-slim

# Add metadata labels
LABEL maintainer="lheritagetyk"
LABEL description="Fake ERP Backend Servers for Kafka Master Data Streaming Demo"

# Set working directory
WORKDIR /app

# Copy the ERP server script
COPY fake_erp_servers.py .

# Create entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Expose ports for all three ERP servers
EXPOSE 8001 8002 8003

# Use entrypoint script to start all servers
ENTRYPOINT ["/docker-entrypoint.sh"]