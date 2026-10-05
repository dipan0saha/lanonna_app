FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app/src

COPY packages/lanonna_activity_copy /packages/lanonna_activity_copy
COPY services/worker/requirements.txt .
RUN pip install --no-cache-dir -e /packages/lanonna_activity_copy -r requirements.txt

COPY services/worker/src ./src
COPY services/worker/email_templates ./email_templates

ENV PORT=8080
CMD ["sh", "-c", "exec uvicorn lanonna_worker.main:app --host 0.0.0.0 --port ${PORT}"]
