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

# Copy the SSH key from the secret environment variable
# Not best practice to store ssh key. will need to change for prod.
ARG SSH_PRIVATE_KEY
RUN mkdir -p /root/.ssh && \
    echo "$SSH_PRIVATE_KEY" > /root/.ssh/id_rsa && \
    chmod 600 /root/.ssh/id_rsa

# Setup SSH config. Add your own domain here to prevent host key verification error.
RUN ssh-keyscan -t rsa github.com >> /root/.ssh/known_hosts

# Install dependencies
RUN uv pip install -e . --system

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
