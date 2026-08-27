from types import SimpleNamespace

from ai_video_editor import tracing


def test_gemini_usage_counts_thinking_as_billable_output():
    response = SimpleNamespace(
        usage_metadata=SimpleNamespace(
            prompt_token_count=19,
            candidates_token_count=1,
            thoughts_token_count=90,
            total_token_count=110,
        )
    )

    input_tokens, output_tokens, total_tokens = tracing.extract_gemini_token_usage(response)

    assert input_tokens == 19
    assert output_tokens == 91
    assert total_tokens == 110


def test_traced_gemini_generate_costs_thinking_tokens(tmp_path):
    response = SimpleNamespace(
        usage_metadata=SimpleNamespace(
            prompt_token_count=100,
            candidates_token_count=10,
            thoughts_token_count=90,
            total_token_count=200,
        )
    )
    client = SimpleNamespace(
        models=SimpleNamespace(generate_content=lambda **_kwargs: response),
    )
    tracer = tracing.ProjectTracer(tmp_path)

    tracing.traced_gemini_generate(
        client,
        model="gemini-3.5-flash",
        contents="prompt",
        config=None,
        phase="test",
        tracer=tracer,
    )

    trace = tracer.traces[0]
    assert trace.input_tokens == 100
    assert trace.output_tokens == 100
    assert trace.total_tokens == 200
    assert trace.estimated_cost_usd == tracing.estimate_cost("gemini-3.5-flash", 100, 100)
