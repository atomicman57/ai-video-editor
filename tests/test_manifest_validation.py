import json

from ai_video_editor.config import load_manifest


def test_load_manifest_accepts_clip_without_embedded_creation_time(tmp_path):
    """Videos exported without camera timestamps remain valid project inputs."""
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "project": "trip",
                "clip_count": 1,
                "total_duration_sec": 4.0,
                "total_duration_fmt": "0:04",
                "clips": [
                    {
                        "clip_id": "arrival",
                        "filename": "arrival.mp4",
                        "source_path": "/tmp/arrival.mp4",
                        "duration_sec": 4.0,
                        "resolution": "1280x720",
                        "fps": "30/1",
                        "creation_time": None,
                    }
                ],
            }
        )
    )

    loaded = load_manifest(manifest_path)

    assert loaded["clips"][0]["creation_time"] is None
