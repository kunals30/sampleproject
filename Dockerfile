FROM python:3.10-slim

WORKDIR /app

COPY pyproject.toml .
RUN pip install .

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]
