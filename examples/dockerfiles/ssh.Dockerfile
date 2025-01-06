# Builder stage
FROM python:3.10-slim as builder

# Set working directory
WORKDIR /app

# Install common build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends git openssh-client && \
    rm -rf /var/lib/apt/lists/*

# Install uv package installer or use your own package installer
RUN pip install uv

# Copy project files
COPY . .

# Create the .ssh directory
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Setup SSH and install dependencies using BuildKit secret mount
# Add your own domain here to prevent host key verification error.
RUN --mount=type=secret,id=ssh,target=/root/.ssh/id_rsa \
    ssh-keyscan -t rsa github.com >> /root/.ssh/known_hosts && \
    uv pip install -e . --system && \
    rm -rf /root/.ssh/known_hosts

# Final stage
FROM python:3.10-slim

ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder /usr/local/lib/python3.10/site-packages/ /usr/local/lib/python3.10/site-packages/
COPY --from=builder /app/ /app/

# expose application port
EXPOSE 8080

# Default command
CMD ["python", "main.py"]