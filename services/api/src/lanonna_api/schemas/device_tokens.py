from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class DeviceTokenUpsertRequest(BaseModel):
    fcm_token: str = Field(min_length=1, max_length=4096)
    platform: Literal["ios", "android"]


class DeviceTokenDeleteRequest(BaseModel):
    fcm_token: str = Field(min_length=1, max_length=4096)
