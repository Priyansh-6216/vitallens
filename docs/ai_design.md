# AI Intelligence Layer Design

The VitalLens AI Coach is more than just a chatbot; it is a **Grounded Reasoning Engine** that translates cold biometric data into empathetic, actionable health advice.

## Core Principles
1.  **Fact-Driven**: The AI does not invent numbers. It receives computed facts from the backend services.
2.  **Explainable**: Every recommendation must give a "Why".
3.  **Context-Aware**: It looks at 7-day and 30-day trends, not just today's score.
4.  **Goal-Oriented**: Tailors advice to the user's specific goals (e.g., "Marathon Training" vs. "General Wellness").

## RAG (Retrieval-Augmented Generation) Strategy
We use **pgvector** to store and retrieve:
- Recent daily summaries and recovery narratives.
- Long-term trend snapshots.
- User-logged health notes and journal entries.
- Scientific context (e.g., "The relationship between alcohol and REM sleep").

## Prompt Orchestration

### Daily Narrative Prompt (System Context)
```text
You are the VitalLens Health Coach. 
Analyze the following user data for [DATE]:
- Recovery Score: 46 (Yellow Band)
- HRV: 42 (-18% vs Baseline)
- RHR: 62 (+9% vs Baseline)
- Sleep Depth: 358m (Debt: 126m)
- Alerts: [Elevated RHR 4-day streak]
- Journal factors: [High Stress, Late Caffeine]

Task: Explain WHY recovery is low and provide 3 priority actions for today. 
Be empathetic but firm about rest.
```

### AI Response Structure (JSON)
The AI Service produces structured output to be consumed by the frontend:
```json
{
  "summary": "Your recovery is struggling today...",
  "key_findings": [
    { "factor": "HRV", "impact": "negative", "description": "18% drop indicates high autonomic stress." },
    { "factor": "Sleep", "impact": "negative", "description": "Cumulative debt is affecting readiness." }
  ],
  "recommendations": [
    "Prioritize 9 hours of sleep tonight.",
    "Limit caffeine after 12 PM.",
    "Active recovery only (Yoga/Walking)."
  ],
  "confidence_score": 0.95
}
```

## Safety & Guardrails
- **Prompt Injection Protection**: Sanitizing user chat inputs.
- **Medical Disclaimer**: Every AI response includes a disclaimer that advice is for wellness, not diagnosis.
- **Hallucination Detection**: Verifying generated stats against the provided data context.
