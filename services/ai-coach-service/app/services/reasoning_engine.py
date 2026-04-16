import os
from openai import OpenAI
from app.models.schemas import HealthContext, InsightResponse

class ReasoningEngine:
    def __init__(self):
        self.client = OpenAI(
            base_url="https://api.groq.com/openai/v1",
            api_key=os.environ.get("GROQ_API_KEY")
        )

    def generate_explanation(self, context: HealthContext) -> InsightResponse:
        system_prompt = """You are the VitalLens Health Coach, a high-performance wellness expert. 
        Analyze the user's daily biometrics and explain the 'Grounding Reason' for their recovery score.
        Be scientific yet empathetic. Focus on the relationship between HRV, RHR, and Sleep."""
        
        user_prompt = f"""
        User Biometrics Today:
        - Recovery Score: {context.recovery_score}%
        - Heart Rate Variability (HRV): {context.hrv} ms
        - Resting Heart Rate (RHR): {context.rhr} bpm
        - Sleep: {context.sleep_duration_min} minutes
        - Critical Alerts: {', '.join(context.alerts) if context.alerts else 'None'}
        
        Note: If the recovery is low, look for elevated RHR or suppressed HRV.
        If recover is high, congratulate them on their physiological readiness.

        Return a JSON response:
        {{
            "summary": "A 2-3 sentence grounded explanation of the recovery level.",
            "key_findings": [{{ "factor": "string", "impact": "positive|negative", "description": "string" }}],
            "recommendations": ["Priority action 1", "Priority action 2", "Priority action 3"],
            "confidence_score": 0.95
        }}
        """

        try:
            response = self.client.chat.completions.create(
                model="llama3-70b-8192",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                response_format={"type": "json_object"}
            )
            
            import json
            content = json.loads(response.choices[0].message.content)
            return InsightResponse(**content)
        except Exception as e:
            print(f"Error calling Groq: {e}")
            # Fallback to mock if API fails
            return InsightResponse(
                summary="We're having trouble reaching the AI coach. Based on your scores, prioritize rest.",
                key_findings=[],
                recommendations=["Rest", "Hydrate", "Sleep"],
                confidence_score=0.5
            )

reasoning_engine = ReasoningEngine()
