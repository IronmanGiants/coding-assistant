FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY coding_agent ./coding_agent
RUN useradd -m agent && mkdir -p /tmp/workspace && chown agent /tmp/workspace
USER agent
EXPOSE 8000
# ADK's built-in chat UI + API, serving every agent folder under /app
CMD ["adk", "web", "--host", "0.0.0.0", "--port", "8000", "/app"]
