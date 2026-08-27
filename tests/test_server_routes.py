from pathlib import Path
from types import SimpleNamespace

from fastapi.testclient import TestClient

from ai_video_editor.server import create_app
from ai_video_editor.server.jobs import REGISTRY
from ai_video_editor.server.routes import _cost, find_rough_cut


def test_find_rough_cut_supports_current_cut_directory_layout(tmp_path):
    exports = tmp_path / "exports"
    expected = exports / "cuts" / "cut_001" / "rough_cut_proxy.mp4"
    expected.parent.mkdir(parents=True)
    expected.write_bytes(b"video")

    project_paths = SimpleNamespace(exports=exports)

    assert find_rough_cut(project_paths) == expected


def test_cost_for_project_without_traces_uses_empty_phase_breakdown():
    summary = _cost("project-without-traces")

    assert summary.calls == 0
    assert summary.by_phase == {}


def test_job_websocket_serializes_path_results(tmp_path):
    job = REGISTRY.submit(
        "cut",
        "websocket-path-result",
        tmp_path,
        lambda: {"rough_cut": Path("exports/cuts/cut_001/rough_cut.mp4")},
    )

    with TestClient(create_app()) as client:
        with client.websocket_connect(f"/jobs/{job.id}/ws") as websocket:
            while True:
                payload = websocket.receive_json()
                if payload["status"] in {"completed", "failed"}:
                    break

    assert payload["status"] == "completed"
    assert payload["result"]["rough_cut"] == "exports/cuts/cut_001/rough_cut.mp4"
