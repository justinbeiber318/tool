from __future__ import annotations

import json

from app.models.config import AppConfig
from app.utils.storage import load_config, save_config


def test_config_does_not_store_username_when_not_remembered(tmp_path) -> None:
    path = tmp_path / "config.json"
    config = AppConfig(username="student01", remember_username=False)

    save_config(config, path)

    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["username"] == ""


def test_config_load_round_trip(tmp_path) -> None:
    path = tmp_path / "config.json"
    config = AppConfig(username="student01", remember_username=True)

    save_config(config, path)
    loaded = load_config(path)

    assert loaded.username == "student01"
    assert loaded.remember_username is True
