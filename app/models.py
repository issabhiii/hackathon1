# app/models.py
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field

class SourceSpan(BaseModel):
    text: str
    bbox: List[float] = Field(default_factory=lambda: [0.0, 0.0, 0.0, 0.0])
    confidence: float = 0.5

class ValueWithMeta(BaseModel):
    value: Optional[str] = None
    unit: Optional[str] = None
    confidence: float = 0.5
    sources: List[SourceSpan] = Field(default_factory=list)

class Dimensions(BaseModel):
    width: Optional[ValueWithMeta] = None
    height: Optional[ValueWithMeta] = None
    depth: Optional[ValueWithMeta] = None
    diagonal: Optional[ValueWithMeta] = None

class Temperature(BaseModel):
    min: Optional[ValueWithMeta] = None
    max: Optional[ValueWithMeta] = None
    rating: Optional[ValueWithMeta] = None

class ExtractedPart(BaseModel):
    part_name: Optional[ValueWithMeta] = None
    manufacturer: Optional[ValueWithMeta] = None
    manufacturer_id: Optional[ValueWithMeta] = None
    function: Optional[ValueWithMeta] = None
    application: Optional[ValueWithMeta] = None
    price: Optional[ValueWithMeta] = None
    weight: Optional[ValueWithMeta] = None
    dimensions: Dimensions = Field(default_factory=Dimensions)
    temperature: Temperature = Field(default_factory=Temperature)
    resolution: Optional[ValueWithMeta] = None
    pressure: Optional[ValueWithMeta] = None
    material: Optional[ValueWithMeta] = None
    features: List[ValueWithMeta] = Field(default_factory=list)

class ExtractResponse(BaseModel):
    model_used: str
    part: ExtractedPart
    raw_text: str
    notes: Optional[str] = None
