defmodule Membrane.SilenceGeneratorTest do
  use ExUnit.Case, async: true
  use Membrane.Pipeline

  import Membrane.Testing.Assertions

  alias Membrane.{AudioMixer, Buffer, SilenceGenerator}
  alias Membrane.Caps.Audio.Raw
  alias Membrane.Testing.{Pipeline, Sink}

  @caps %Raw{
    channels: 1,
    sample_rate: 16_000,
    format: :s16le
  }

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

    assert Pipeline.play(pid) == :ok
    assert_start_of_stream(pid, :sink)

    assert_sink_buffer(pid, :sink, %Buffer{payload: payload_1})
    assert_sink_buffer(pid, :sink, %Buffer{payload: payload_2})

    assert_end_of_stream(pid, :sink, :input, 5_000)
    Pipeline.stop_and_terminate(pid, blocking?: true)

    assert payload_1 <> payload_2 == Raw.sound_of_silence(@caps, duration)
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

    assert Pipeline.play(pid) == :ok
    assert_start_of_stream(pid, :sink)

    assert_sink_buffer(pid, :sink, %Buffer{payload: payload_1})
    assert_sink_buffer(pid, :sink, %Buffer{payload: payload_2})

    assert_end_of_stream(pid, :sink, :input, 5_000)
    Pipeline.stop_and_terminate(pid, blocking?: true)

    assert payload_1 <> payload_2 == Raw.sound_of_silence(@caps, duration)
  end
end
