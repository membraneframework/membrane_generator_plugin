defmodule Membrane.SilenceGeneratorTest do
  use ExUnit.Case, async: true
  use Membrane.Pipeline

  import Membrane.Testing.Assertions

  alias Membrane.{AudioMixer, Buffer, SilenceGenerator}
  alias Membrane.RawAudio
  alias Membrane.Testing.{Pipeline, Sink}

  @caps %RawAudio{
    channels: 1,
    sample_rate: 16_000,
    sample_format: :s16le
  }

  defp gather_payloads(pid, acc \\ <<>>, target_size)

  defp gather_payloads(pid, acc, target_size) when byte_size(acc) < target_size do
    assert_sink_buffer(pid, :sink, %Buffer{payload: payload})
    gather_payloads(pid, acc <> payload, target_size)
  end

  defp gather_payloads(pid, acc, _target_size) do
    refute_sink_buffer(pid, :sink, %Buffer{})
    acc
  end

  test "Silence Generator should work with bytes as demand unit" do
    duration = Membrane.Time.seconds(4)

    elements = [
      generator: %SilenceGenerator{caps: @caps, duration: duration},
      mixer: %AudioMixer{caps: @caps, prevent_clipping: false},
      sink: Sink
    ]

    links = [
      link(:generator)
      |> to(:mixer)
      |> to(:sink)
    ]

    pipeline_options = %Pipeline.Options{elements: elements, links: links}
    assert {:ok, pid} = Pipeline.start_link(pipeline_options)

    assert_start_of_stream(pid, :sink)

    payload = gather_payloads(pid, RawAudio.time_to_bytes(duration, @caps))

    assert_end_of_stream(pid, :sink, :input, 5_000)
    Pipeline.terminate(pid, blocking?: true)

    assert payload == RawAudio.silence(@caps, duration)
  end

  test "Silence Generator should work with buffers as demand unit" do
    duration = Membrane.Time.seconds(6)

    elements = [
      generator: %SilenceGenerator{caps: @caps, duration: duration},
      sink: Sink
    ]

    links = [
      link(:generator)
      |> to(:sink)
    ]

    pipeline_options = %Pipeline.Options{elements: elements, links: links}
    assert {:ok, pid} = Pipeline.start_link(pipeline_options)

    assert_start_of_stream(pid, :sink)

    payload = gather_payloads(pid, RawAudio.time_to_bytes(duration, @caps))

    assert_end_of_stream(pid, :sink, :input, 5_000)
    Pipeline.terminate(pid, blocking?: true)

    assert payload == RawAudio.silence(@caps, duration)
  end
end
