from pydantic import BaseModel, Field
from typing import List, Literal, Optional


class CaseInfo(BaseModel):
    """Patient case information"""
    symptoms: List[str] = Field(description="List of symptoms reported by the patient")
    duration_days: Optional[int] = Field(default=None, description="Number of days the symptoms have persisted")


class ImmediateAction(BaseModel):
    """Immediate precautions and actions to take"""
    precautions: List[str] = Field(
        description="List of immediate precautions the patient should take right now"
    )
    what_to_do: List[str] = Field(
        description="List of immediate actions or remedies the patient should do"
    )
    warning_signs: List[str] = Field(
        description="Warning signs that require immediate medical attention"
    )


class FollowUp(BaseModel):
    """Follow-up information"""
    scheduled_after_hours: int = Field(description="Number of hours after which to follow up")
    questions: List[str] = Field(
        description="List of specific follow-up questions to ask the patient about their condition"
    )


class MedicalTriageResponse(BaseModel):
    """Structured medical triage response"""
    case: CaseInfo = Field(description="Patient case details")
    risk_level: Literal["green", "yellow", "red"] = Field(
        description="Risk assessment level: green (low), yellow (moderate), red (high)"
    )
    immediate_action: ImmediateAction = Field(
        description="Immediate precautions and actions to take right now"
    )
    follow_up: FollowUp = Field(description="Follow-up schedule and questions")


