from fastapi import FastAPI, Depends
from app.api.endpoints import coach_router

app = FastAPI(title="VitalLens AI Coach Service")

@app.get("/")
def read_root():
    return {"status": "ok", "service": "ai-coach-service"}

app.include_router(coach_router, prefix="/api/v1/ai", tags=["coach"])
