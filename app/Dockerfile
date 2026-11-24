FROM python:3.12-slim

WORKDIR /app

VOLUME /data

COPY requirements.txt .

RUN pip install -r requirements.txt

COPY . .

USER 10001:10001

EXPOSE 8000

CMD ["python", "app.py"]
