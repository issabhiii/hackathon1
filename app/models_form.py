from typing import Optional, List, Literal
from pydantic import BaseModel, Field

class KVPair(BaseModel):
    key: str
    value: str

class ACF(BaseModel):
    application: Optional[str] = None
    category: Optional[str] = None
    function: Optional[str] = None

class SpecPayload(BaseModel):
    # Header (UI usually fills these)
    applicant: Optional[str] = None
    team: Optional[str] = None

    # Part / Manufacturer
    part_name: Optional[str] = None
    manufacturer: Optional[str] = None
    manufacturer_id: Optional[str] = None
    include_previous_manufacturer_info: Optional[bool] = None

    # ACF triplet
    acf: ACF = Field(default_factory=ACF)

    # Reason & Description
    reason: Optional[str] = None
    description: Optional[str] = None

    # Physical (key–value pairs)
    physical: List[KVPair] = Field(default_factory=list)

    # Status & Notes
    status: Literal["Normal", "Urgent"] = "Normal"
    notes: Optional[str] = None
