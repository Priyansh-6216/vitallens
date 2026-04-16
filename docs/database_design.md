# Database Design

## Database Strategy
- **PostgreSQL**: Primary transactional database.
- **TimescaleDB**: Extension for efficient time-series storage of biometric samples.
- **pgvector**: For semantic search and RAG (Retrieval-Augmented Generation) in the AI Coach Service.

## Core Schema Groups

### 1. Identity & Profile
- `users`: Core account data.
- `user_profiles`: Demographics (age, sex, height, weight).
- `user_goals`: Personalized fitness and sleep targets.

### 2. Device & Metrics
- `device_connections`: Linked wearable providers.
- `biometric_samples` (Hypertable): Raw streams (HRV, RHR, Respiratory Rate, etc.).
- `daily_sleep_summary`: Aggregated sleep performance.
- `daily_recovery_summary`: Readiness scores and contributing factors.
- `daily_strain_summary`: Training load vs. target.

### 3. Journal & Habits
- `journal_entries`: User-logged behaviors (alcohol, caffeine, stress).
- `habit_correlations`: Computed impact of habits on recovery scores.

### 4. AI & Alerts
- `ai_generated_insights`: Explanations and narratives stored for retrieval.
- `ai_conversations`: History of coaching chat.
- `alerts`: Anomaly flags (low recovery streaks, elevated RHR).

## SQL Schema Definition (Sample)

```sql
-- Users and Profiles
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE user_profiles (
    user_id UUID REFERENCES users(id),
    first_name TEXT,
    last_name TEXT,
    dob DATE,
    sex TEXT,
    height_cm NUMERIC,
    weight_kg NUMERIC,
    timezone TEXT,
    PRIMARY KEY (user_id)
);

-- Biometrics (Time-series)
CREATE TABLE biometric_samples (
    time TIMESTAMPTZ NOT NULL,
    user_id UUID REFERENCES users(id),
    metric_type TEXT NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    unit TEXT,
    source TEXT
);

-- Select extension for TimescaleDB if available
-- SELECT create_hypertable('biometric_samples', 'time');

-- Daily Recovery Summary
CREATE TABLE daily_recovery_summary (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    day DATE NOT NULL,
    recovery_score INT CHECK (recovery_score BETWEEN 0 AND 100),
    readiness_band TEXT, -- 'green', 'yellow', 'red'
    hrv NUMERIC,
    resting_hr NUMERIC,
    top_factors_json JSONB,
    UNIQUE(user_id, day)
);

-- AI Insights with Vector Support
CREATE TABLE ai_generated_insights (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    day DATE NOT NULL,
    insight_type TEXT,
    content TEXT,
    embedding VECTOR(1536), -- For retrieval via pgvector
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```
