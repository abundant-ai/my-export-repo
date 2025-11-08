FROM python:3.11-slim

# Set working directory for all subsequent commands
WORKDIR /app

# Install Python, pytest, requests, tmux, and asciinema for testing
RUN apt-get update && apt-get install -y python3 python3-pip tmux asciinema \
    && pip3 install --break-system-packages pytest requests \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy sample code for testing
RUN mkdir -p /app/code_to_review
COPY sample_code/*.py /app/code_to_review/

# Optionally remove VCS metadata if present (safe for tasks without /app/src)
RUN if [ -d /app/src/.git ]; then rm -rf /app/src/.git; fi || true
