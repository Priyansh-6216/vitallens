# API Specification

The VitalLens API is versioned (`/api/v1`) and uses standard REST conventions. All requests require a valid JWT in the `Authorization` header.

## 1. Auth & User
- `POST /auth/register`: Create a new account.
- `POST /auth/login`: Authenticate and receive tokens.
- `GET /users/me`: Fetch current user profile.
- `PUT /users/me`: Update profile details (goals, biometric baseline).

## 2. Recovery & Readiness
- `GET /recovery/today`: Fetch the recovery score for the current day.
- `GET /recovery/history?range=30d`: Fetch historical recovery trends.
- `GET /readiness/today`: Fetch the readiness classification ('green', 'yellow', 'red').

## 3. Sleep & Strain
- `GET /sleep/today`: Fetch sleep summary (duration, efficiency, debt).
- `GET /sleep/planner`: Get suggested bedtime based on sleep debt and tomorrow's goals.
- `GET /strain/today`: Fetch current activity strain.
- `GET /strain/target`: Fetch the recommended strain target for today.
- `POST /workouts`: Log a manual workout session.

## 4. Journaling
- `POST /journal/entries`: Log daily habits or symptoms.
- `GET /journal/entries?range=7d`: View recent journal history.

## 5. AI Coach
- `POST /ai/chat`: Interactive chat with the AI coach.
- `GET /ai/explain-recovery`: Get a detailed narrative explanation of today's recovery.
- `GET /ai/weekly-summary`: Generate a rolling weekly trend analysis.

## 6. Alerts & Reports
- `GET /alerts`: Fetch active health alerts or anomalies.
- `POST /reports/generate`: Request a PDF export (Summary/Medical).

---

### Sample Response: `GET /recovery/today`
```json
{
  "day": "2026-04-15",
  "recovery_score": 46,
  "readiness_band": "yellow",
  "top_factors": [
    "HRV is 18% below baseline",
    "Sleep debt: 126 mins"
  ],
  "ai_summary": "Your recovery is lower than normal. Focus on hydration and early sleep.",
  "recommended_strain": 9.2
}
```
