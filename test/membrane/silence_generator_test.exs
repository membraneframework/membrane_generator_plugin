defmodule Membrane.SilenceGeneratorTest do
  use ExUnit.Case, async: true
  use Membrane.Pipeline

  import Membrane.Testing.Assertions
  import Membrane.ChildrenSpec

  alias Membrane.{AudioMixer, Buffer, SilenceGenerator}
  alias Membrane.RawAudio
  alias Membrane.Testing.{Pipeline, Sink}

  @stream_format %RawAudio{
    channels: 1,
    sample_rate: 16_000,
    sample_format: :s16le
  }

  defp gather_payloads(pipeline, acc \\ <<>>, target_size)

  defp gather_payloads(pipeline, acc, target_size) when byte_size(acc) < target_size do
    assert_sink_buffer(pipeline, :sink, %Buffer{payload: payload})
    gather_payloads(pipeline, acc <> payload, target_size)
  end

  defp gather_payloads(pipeline, acc, _target_size) do
    refute_sink_buffer(pipeline, :sink, %Buffer{})
    acc
  end

  test "Silence Generator should work with bytes as demand unit" do
    duration = Membrane.Time.seconds(4)

    structure =
      child(:generator, %SilenceGenerator{stream_format: @stream_format, duration: duration})
      |> child(:mixer, %AudioMixer{stream_format: @stream_format, prevent_clipping: false})
      |> child(:sink, Sink)

    pipeline = Pipeline.start_link_supervised!(structure: structure)

    assert_start_of_stream(pipeline, :sink)

    payload = gather_payloads(pipeline, RawAudio.time_to_bytes(duration, @stream_format))

    assert_end_of_stream(pipeline, :sink, :input, 5_000)
    Pipeline.terminate(pipeline, blocking?: true)

    assert payload == RawAudio.silence(@stream_format, duration)
  end

  test "Silence Generator should work with buffers as demand unit" do
    duration = Membrane.Time.seconds(6)

    structure =
      child(:generator, %SilenceGenerator{stream_format: @stream_format, duration: duration})
      |> child(:sink, Sink)

    pipeline = Pipeline.start_link_supervised!(structure: structure)

    assert_start_of_stream(pipeline, :sink)

    payload = gather_payloads(pipeline, RawAudio.time_to_bytes(duration, @stream_format))

    assert_end_of_stream(pipeline, :sink, :input, 5_000)
    Pipeline.terminate(pipeline, blocking?: true)

    assert payload == RawAudio.silence(@stream_format, duration)
  end
end
