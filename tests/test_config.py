from ai_video_editor.config import GeminiConfig, TranscribeConfig


def test_default_gemini_pipeline_uses_current_generation_models():
    gemini = GeminiConfig()

    assert gemini.model == "gemini-3.5-flash"
    assert gemini.phase2 == "gemini-3.5-flash"
    assert gemini.structuring_model == "gemini-3.5-flash-lite"
    assert gemini.phase2b == "gemini-3.5-flash"
    assert TranscribeConfig().gemini_model == "gemini-3.5-flash"
