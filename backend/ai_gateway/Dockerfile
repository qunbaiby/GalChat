FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN addgroup --system galchat && adduser --system --ingroup galchat galchat

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py auth.py email_service.py maintenance.py preflight.py provider_secrets.py storage.py admin.html ./

RUN mkdir -p /data/backups && chown -R galchat:galchat /app /data

USER galchat

EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8787/ready', timeout=3).read()"]

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8787", "--proxy-headers", "--forwarded-allow-ips=*"]