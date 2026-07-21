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
import html
import os
import secrets
import sqlite3
from datetime import datetime, timezone

from cryptography.fernet import Fernet
from fastapi import Depends, FastAPI, Form, Header, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from pydantic import BaseModel

DB_PATH = os.environ["RESCUE_DB_PATH"]
DEVICE_WRITE_TOKEN = os.environ["DEVICE_WRITE_TOKEN"]
STAFF_READ_TOKEN = os.environ["STAFF_READ_TOKEN"]
fernet = Fernet(os.environ["RESCUE_ENC_KEY"].encode())

# docs/redoc/openapi.json desactivados: quedaban publicos sin autenticacion,
# exponiendo la estructura de la API (incluida la existencia de
# /rescue-credentials) a cualquiera. /soporte cubre ya el caso de uso humano.
app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
basic_auth = HTTPBasic()


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


def require_staff_basic_auth(credentials: HTTPBasicCredentials = Depends(basic_auth)):
    # Usuario libre (el navegador exige rellenar algo), solo la contraseña
    # importa: es el mismo STAFF_READ_TOKEN que ya usa el GET JSON. compare_digest
    # evita filtrar el token por diferencias de tiempo en la comparación.
    if not secrets.compare_digest(credentials.password, STAFF_READ_TOKEN):
        raise HTTPException(
            status_code=401,
            detail="no autorizado",
            headers={"WWW-Authenticate": "Basic"},
        )


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


def _fetch_credential(rustdesk_id: str):
    conn = get_db()
    try:
        row = conn.execute(
            "SELECT password_enc, created_at FROM rescue_credentials WHERE rustdesk_id = ?",
            (rustdesk_id,),
        ).fetchone()
    finally:
        conn.close()
    if row is None:
        return None
    return {
        "rustdesk_id": rustdesk_id,
        "password": fernet.decrypt(row[0]).decode(),
        "created_at": row[1],
    }


@app.get("/rescue-credentials/{rustdesk_id}")
def lookup(rustdesk_id: str, authorization: str = Header(...)):
    require_bearer(authorization, STAFF_READ_TOKEN)

    credential = _fetch_credential(rustdesk_id)
    if credential is None:
        raise HTTPException(status_code=404, detail="sin registro para ese id")
    return credential


_LOOKUP_PAGE = """<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<title>Solwed OS - contraseña de rescate</title>
<style>
  body {{ font-family: system-ui, sans-serif; max-width: 420px; margin: 60px auto; padding: 0 16px; color: #222; }}
  label {{ font-weight: 600; display: block; margin-top: 8px; }}
  input {{ width: 100%; box-sizing: border-box; padding: 8px; font-size: 1rem; margin-top: 4px; }}
  button {{ margin-top: 14px; padding: 8px 18px; font-size: 1rem; cursor: pointer; }}
  .result {{ margin-top: 22px; padding: 14px; background: #f2f2f2; border-radius: 8px; }}
  .password {{ font-family: monospace; font-size: 1.15rem; user-select: all; }}
  .error {{ color: #b00020; margin-top: 22px; }}
</style></head>
<body>
  <h2>Contraseña de rescate soporte-solwed</h2>
  <form method="post" action="/soporte">
    <label for="rustdesk_id">ID de RustDesk (el que lee el cliente en pantalla)</label>
    <input id="rustdesk_id" name="rustdesk_id" value="{rustdesk_id}" pattern="[0-9]+" required autofocus>
    <button type="submit">Consultar</button>
  </form>
  {result}
</body></html>"""


def _render_lookup_page(rustdesk_id: str) -> str:
    result_html = ""
    if rustdesk_id:
        if not rustdesk_id.isdigit():
            result_html = '<p class="error">El ID solo puede tener digitos.</p>'
        else:
            credential = _fetch_credential(rustdesk_id)
            if credential is None:
                result_html = f'<p class="error">Sin registro para el ID {html.escape(rustdesk_id)}.</p>'
            else:
                result_html = f"""<div class="result">
                    <div>ID: {html.escape(credential['rustdesk_id'])}</div>
                    <div>Contraseña: <span class="password">{html.escape(credential['password'])}</span></div>
                    <div>Generada: {html.escape(credential['created_at'])}</div>
                </div>"""
    return _LOOKUP_PAGE.format(rustdesk_id=html.escape(rustdesk_id), result=result_html)


@app.get("/soporte", response_class=HTMLResponse)
def soporte_form(_staff=Depends(require_staff_basic_auth)):
    return _render_lookup_page("")


@app.post("/soporte", response_class=HTMLResponse)
def soporte_lookup(rustdesk_id: str = Form(...), _staff=Depends(require_staff_basic_auth)):
    return _render_lookup_page(rustdesk_id)
