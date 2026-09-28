FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app/src

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src ./src

ENV PORT=8080
CMD ["sh", "-c", "exec uvicorn lanonna_api.main:app --host 0.0.0.0 --port ${PORT}"]
