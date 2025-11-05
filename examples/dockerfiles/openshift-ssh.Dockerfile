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

# create virtual environment
RUN uv venv /opt/venv

# Place entry points in the environment at the front of the path
ENV PATH="/opt/venv/bin:$PATH"

# Copy project files
COPY . .

# In OpenShift Buildah SSH secret is volume mounted instead of BuildKit
RUN eval "$(ssh-agent -s)" && \
    ssh-add /root/.ssh/ssh-privatekey && \
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" uv pip install --no-cache .

# Final stage
FROM python:3.10-slim

ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/ /app/

# expose application port
EXPOSE 8080

# Default command
CMD ["python", "main.py"]
