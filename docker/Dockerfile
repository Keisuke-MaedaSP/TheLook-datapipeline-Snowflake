FROM python:3.12.16-slim
WORKDIR /app

COPY requirements.freeze.txt ./
RUN python -m pip install --no-cache-dir -r requirements.freeze.txt

CMD ["python", "--version"]
