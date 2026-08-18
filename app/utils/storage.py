from __future__ import annotations

import json
from pathlib import Path

from app.models.config import AppConfig, default_config_path


def load_config(path: Path | None = None) -> AppConfig:
    config_path = path or default_config_path()
    if not config_path.exists():
        return AppConfig()
    with config_path.open("r", encoding="utf-8") as file:
        return AppConfig.from_dict(json.load(file))


def save_config(config: AppConfig, path: Path | None = None) -> None:
    config_path = path or default_config_path()
    config_path.parent.mkdir(parents=True, exist_ok=True)
    with config_path.open("w", encoding="utf-8") as file:
        json.dump(config.to_safe_dict(), file, ensure_ascii=False, indent=2)
