# VitalLens AI 🧬

VitalLens AI is a production-grade health intelligence platform designed to bridge the gap between complex biometric data and actionable behavioral insights. Inspired by WHOOP, it leverages a distributed microservices architecture to provide real-time recovery analysis and personalized AI coaching.

![Dashboard Preview](https://via.placeholder.com/1200x600/1a1c20/00ff88?text=VitalLens+AI+Dashboard+Visuals)

## 🌟 Key Features

- **Live WHOOP Sync**: Seamlessly integrate your WHOOP recovery metrics via OAuth 2.0.
- **AI Coach Insights**: Get grounded, scientific explanations for your recovery scores using LLMs (Llama 3 via Groq).
- **Core Biometrics**: Track HRV (Heart Rate Variability), RHR (Resting Heart Rate), and Sleep Cycles with high-fidelity visualizations.
- **Secure Persistence**: Enterprise-grade data isolation using per-service PostgreSQL databases.
- **Event-Driven Architecture**: Fast, reactive updates powered by Kafka.

## 🏗️ Architecture

VitalLens is built as an asynchronous microservices system:

- **Dashboard Service**: React/Vite/Tailwind frontend with Recharts for premium data visuals.
- **API Gateway**: Centralized routing and cross-cutting concerns management (Spring Cloud Gateway).
- **Recovery Service**: The core engine for biometric ingestion and score computation (Spring Boot).
- **AI Coach Service**: Python/FastAPI service orchestrating LLM reasoning logic and health narratives.
- **Infrastructure**: Fully containerized using Docker & Docker Compose.

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Java 17+ (for local development)
- Node.js 18+ (for local development)

### Setup
1. **Clone the repository**:
   ```bash
   git clone https://github.com/Priyansh-6216/vitallens.git
   cd vitallens
   ```

2. **Configure environment**:
   ```bash
   cp infra/.env.example infra/.env
   # Edit infra/.env with your GROQ_API_KEY and WHOOP credentials
   ```

3. **Launch the platform**:
   ```bash
   docker-compose -f infra/docker-compose.yml up --build
   ```

4. **Access the Dashboard**:
   Open [http://localhost:5173](http://localhost:5173) in your browser.

## 🛠️ Tech Stack

- **Backend**: Spring Boot 3.1, Java 17, Python 3.10, FastAPI
- **Frontend**: React, Vite, Recharts, Lucide Icons
- **Data & Ops**: PostgreSQL, Redis, Kafka, Docker
- **AI**: Groq API (Llama 3-70B)

## 📝 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
