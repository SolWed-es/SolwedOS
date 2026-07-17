# Solwed OS - servicio de contraseñas de rescate de soporte-solwed.
#
# Dos tokens separados a propósito:
#   - DEVICE_WRITE_TOKEN: horneado en TODAS las imágenes de Solwed OS. Solo
#     permite crear un registro NUEVO (write-once, ver /rescue-credentials
#     POST) — nunca leer ni sobrescribir uno existente. Si se filtra, el
#     daño posible es limitado a "basura" para IDs nuevos, no acceso a
#     contraseñas reales ya guardadas.
#   - STAFF_READ_TOKEN: solo en manos del equipo de soporte, nunca en
#     ninguna imagen de cliente. Es el único que permite el GET que
#     devuelve la contraseña en claro.
#
# La contraseña se guarda cifrada en reposo (Fernet) para que un volcado del
# fichero sqlite por sí solo no filtre nada en claro.
import os
import sqlite3
from datetime import datetime, timezone

from cryptography.fernet import Fernet
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

DB_PATH = os.environ["RESCUE_DB_PATH"]
DEVICE_WRITE_TOKEN = os.environ["DEVICE_WRITE_TOKEN"]
STAFF_READ_TOKEN = os.environ["STAFF_READ_TOKEN"]
fernet = Fernet(os.environ["RESCUE_ENC_KEY"].encode())

app = FastAPI()


def get_db():
    # WAL: permite lecturas concurrentes mientras hay una escritura en
    # curso, en vez del locking exclusivo del modo journal por defecto.
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute(
        """CREATE TABLE IF NOT EXISTS rescue_credentials (
            rustdesk_id TEXT PRIMARY KEY,
            password_enc BLOB NOT NULL,
            created_at TEXT NOT NULL
        )"""
    )
    return conn


def require_bearer(authorization: str, expected: str):
    if authorization != f"Bearer {expected}":
        raise HTTPException(status_code=401, detail="no autorizado")


class RegisterBody(BaseModel):
    rustdesk_id: str
    password: str


@app.post("/rescue-credentials", status_code=201)
def register(body: RegisterBody, authorization: str = Header(...)):
    require_bearer(authorization, DEVICE_WRITE_TOKEN)

    if not body.rustdesk_id.isdigit() or len(body.rustdesk_id) < 6:
        raise HTTPException(status_code=400, detail="rustdesk_id invalido")
    if len(body.password) < 12:
        raise HTTPException(status_code=400, detail="password demasiado corta")

    conn = get_db()
    try:
        try:
            conn.execute(
                "INSERT INTO rescue_credentials (rustdesk_id, password_enc, created_at) VALUES (?, ?, ?)",
                (
                    body.rustdesk_id,
                    fernet.encrypt(body.password.encode()),
                    datetime.now(timezone.utc).isoformat(),
                ),
            )
            conn.commit()
        except sqlite3.IntegrityError:
            # Ya registrado — write-once. El script de primer arranque trata
            # esto como éxito (idempotente), no lo interpretes como ataque sin
            # más contexto, pero sí merece mirarlo si se repite mucho.
            raise HTTPException(status_code=409, detail="ya registrado")
    finally:
        conn.close()
    return {"status": "ok"}


@app.get("/rescue-credentials/{rustdesk_id}")
def lookup(rustdesk_id: str, authorization: str = Header(...)):
    require_bearer(authorization, STAFF_READ_TOKEN)

    conn = get_db()
    try:
        row = conn.execute(
            "SELECT password_enc, created_at FROM rescue_credentials WHERE rustdesk_id = ?",
            (rustdesk_id,),
        ).fetchone()
    finally:
        conn.close()
    if row is None:
        raise HTTPException(status_code=404, detail="sin registro para ese id")

    return {
        "rustdesk_id": rustdesk_id,
        "password": fernet.decrypt(row[0]).decode(),
        "created_at": row[1],
    }
