from pydantic import BaseModel


class UserEngagementStats(BaseModel):
    photos_squished: int
    events_attended: int
    items_bought: int
    comments: int


class StorageUsage(BaseModel):
    used_bytes: int
    quota_bytes: int
