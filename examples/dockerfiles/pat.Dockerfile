# Stage 1: Builder (for OpenShift)
# This Dockerfile is optimized for OpenShift builds, using Github token authentication.
FROM python:3.10-slim-bookworm AS builder

# Set the working directory
WORKDIR /app

# Install dependencies required for the build
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git && \
    rm -rf /var/lib/apt/lists/*

# Install uv, the Python package manager
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Copy project files
COPY pyproject.toml uv.lock .python-version ./

# Validate credentials are present (optional debug step)
RUN test -n "${GITHUB_USERNAME}" || (echo "ERROR: GITHUB_USERNAME is empty" && exit 1)
RUN test -n "${GITHUB_TOKEN}" || (echo "ERROR: GITHUB_TOKEN is empty" && exit 1)

# Use credentials for git
RUN git config --global url."https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.ibm.com/".insteadOf "https://github.ibm.com/"

# Install dependencies using Github token authentication
RUN uv sync --no-cache

# ---

# Stage 2: Final Image
# This stage creates the final, lightweight production image.
FROM python:3.10-slim-bookworm

RUN apt-get update && apt-get install -y redis-server && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy the virtual environment from the builder stage
COPY --from=builder /app/.venv ./.venv

# Copy the application source code
COPY src/ ./src/

ENV \
    HF_HOME="/tmp/.cache/huggingface" \
    MPLCONFIGDIR="/tmp/.config/matplotlib" \
    LOGGING_CONFIG_PATH="/tmp/app.log" \
    gt4sd_local_cache_path="/tmp/.openad_models"

# Set the entrypoint for the container
CMD ["/bin/sh", "-c", "redis-server --dir /data & ./.venv/bin/python src/wrapper.py"]