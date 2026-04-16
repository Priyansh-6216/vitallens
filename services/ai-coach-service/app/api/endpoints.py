from fastapi import APIRouter
from app.models.schemas import HealthContext, InsightResponse
from app.services.reasoning_engine import reasoning_engine

coach_router = APIRouter()

@coach_router.post("/explain-recovery", response_model=InsightResponse)
def explain_recovery(context: HealthContext):
    return reasoning_engine.generate_explanation(context)

@coach_router.post("/chat")
def chat_with_coach(user_id: str, query: str):
    # Logic for RAG-based chat would go here
    return {
        "user_id": user_id,
        "query": query,
        "response": "I'm analyzing your trends. It looks like your sleep debt has been higher than normal this week."
    }
