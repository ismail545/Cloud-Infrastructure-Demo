# 🐍 Base image: slim & small for production
FROM python:3.11-slim

# 🧭 Set working directory
WORKDIR /app

# 📜 Copy requirements first for better caching
COPY requirements.txt requirements.txt

# 📦 Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# 📂 Copy the rest of the app code
COPY . .

# 🌍 Set environment variables
ENV FLASK_ENV=production
ENV PORT=5000

# 🔐 Listen on all interfaces
EXPOSE 5000

# 🐳 Command to run the app with gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]