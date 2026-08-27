from ai_video_editor import editorial_phase2


def test_current_gemini_structured_output_omits_legacy_thinking_budget():
    config_factory = getattr(editorial_phase2, "_gemini_structured_output_config", None)

    assert config_factory is not None

    config = config_factory(temperature=0.2)

    assert config.response_mime_type == "application/json"
    assert config.thinking_config is None
