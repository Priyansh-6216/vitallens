from pydantic import BaseModel
from typing import List, Optional
from datetime import date

class HealthContext(BaseModel):
    user_id: str
    day: date
    recovery_score: int
    hrv: float
    rhr: float
    sleep_duration_min: int
    sleep_debt_min: int
    alerts: List[str]
    journal_factors: List[str]

class InsightResponse(BaseModel):
    summary: str
    key_findings: List[dict]
    recommendations: List[str]
    confidence_score: float
