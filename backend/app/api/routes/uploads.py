import uuid
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request, UploadFile

from app.api.deps import CurrentUser
from app.core.config import get_settings

router = APIRouter(prefix="/uploads", tags=["Fichiers"])

ALLOWED = {"image/png": ".png", "image/jpeg": ".jpg", "image/webp": ".webp", "image/svg+xml": ".svg"}
MAX_BYTES = 5 * 1024 * 1024


@router.post("", status_code=201)
async def upload(file: UploadFile, request: Request, user: CurrentUser):
    ext = ALLOWED.get(file.content_type or "")
    if ext is None:
        raise HTTPException(400, "Format d'image non supporté")
    content = await file.read()
    if len(content) > MAX_BYTES:
        raise HTTPException(400, "Fichier trop volumineux (5 Mo max)")
    folder = Path(get_settings().upload_dir)
    folder.mkdir(parents=True, exist_ok=True)
    name = f"{uuid.uuid4().hex}{ext}"
    (folder / name).write_bytes(content)
    return {"url": str(request.base_url).rstrip("/") + f"/uploads/{name}"}
