"""Run the sidecar: ``python -m ai_video_editor.server`` (or via ``vx serve``).

Honors VX_HOST / VX_PORT env vars; defaults to 127.0.0.1:8765.
"""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv


def main():
    # The native app starts the sidecar with the repository as its working
    # directory. Load that project's ignored .env before reading server or
    # provider settings so GEMINI_API_KEY is available to analysis jobs.
    load_dotenv(dotenv_path=Path.cwd() / ".env")

    import uvicorn

    host = os.environ.get("VX_HOST", "127.0.0.1")
    port = int(os.environ.get("VX_PORT", "8765"))
    uvicorn.run("ai_video_editor.server.app:app", host=host, port=port, log_level="info")


if __name__ == "__main__":
    main()
