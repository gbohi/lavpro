from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, field_validator


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    @field_validator("*", mode="after")
    @classmethod
    def _utc_aware(cls, v):
        # Les dates sont stockées en UTC "naïf" : on les expose en UTC explicite.
        if isinstance(v, datetime) and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v


class Message(BaseModel):
    detail: str


class Page[T](BaseModel):
    items: list[T]
    total: int
    page: int
    size: int
