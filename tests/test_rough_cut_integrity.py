from pathlib import Path
from subprocess import CompletedProcess

from ai_video_editor import rough_cut
from ai_video_editor.rough_cut import CompatibilityTarget, SegmentProbe


def test_reencode_without_output_format_uses_compatibility_target(tmp_path, monkeypatch):
    segment = tmp_path / "segment.mp4"
    segment.write_bytes(b"source")
    commands: list[list[str]] = []

    def fake_run(command, **_kwargs):
        commands.append(command)
        if "-vf" in command:
            Path(command[-1]).write_bytes(b"reencoded")
        return CompletedProcess(command, 0, "", "")

    monkeypatch.setattr(rough_cut.subprocess, "run", fake_run)
    target = CompatibilityTarget(
        video_codec="h264",
        width=1280,
        height=720,
        pix_fmt="yuv420p",
        fps=30.0,
        audio_sample_rate=48000,
        audio_channels=2,
    )

    assert rough_cut._reencode_segment(segment, None, target)

    reencode_command = next(command for command in commands if "-vf" in command)
    video_filter = reencode_command[reencode_command.index("-vf") + 1]
    assert "scale=1280:720" in video_filter
    assert "fps=30.0" in video_filter


def test_verify_rough_cut_rejects_short_video_stream(tmp_path, monkeypatch):
    output = tmp_path / "rough_cut.mp4"
    output.write_bytes(b"x" * 30_000)
    probe = SegmentProbe(
        path=output,
        duration=8.0,
        video_duration=6.25,
        audio_duration=8.0,
        has_video=True,
        has_audio=True,
        file_size=output.stat().st_size,
    )
    monkeypatch.setattr(rough_cut, "_probe_segment", lambda _path: probe)
    monkeypatch.setattr(
        rough_cut.subprocess,
        "run",
        lambda *args, **kwargs: CompletedProcess(args[0], 0, "frame\n", ""),
    )

    errors = rough_cut._verify_rough_cut(output, expected_duration=8.0, segment_count=2)

    assert any("video stream duration" in error for error in errors)


def test_compatibility_check_returns_explicit_majority_target_when_no_probe_matches():
    probes = [
        SegmentProbe(
            path=Path("one.mp4"),
            video_codec="h264",
            width=1280,
            height=720,
            pix_fmt="yuv420p",
            fps=24.0,
            has_video=True,
        ),
        SegmentProbe(
            path=Path("two.mp4"),
            video_codec="h264",
            width=1920,
            height=1080,
            pix_fmt="yuv420p10le",
            fps=30.0,
            has_video=True,
        ),
        SegmentProbe(
            path=Path("three.mp4"),
            video_codec="hevc",
            width=1280,
            height=720,
            pix_fmt="yuv420p10le",
            fps=30.0,
            has_video=True,
        ),
    ]

    _warnings, incompatible_indices, target = rough_cut._check_segment_compatibility(probes)

    assert incompatible_indices == [0, 1, 2]
    assert target.video_codec == "h264"
    assert (target.width, target.height) == (1280, 720)
    assert target.pix_fmt == "yuv420p10le"
    assert target.fps == 30.0
