FROM python:3.10-slim

WORKDIR /app

# Copy built wheel
COPY dist/*.whl /app/

# Install the wheel
RUN pip install --no-cache-dir *.whl

# (Optional) if your app exposes a port
# EXPOSE 8000

# Adjust module name if needed
CMD ["python", "-m", "sampleproject"]
