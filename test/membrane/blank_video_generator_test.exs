defmodule Membrane.BlankVideoGeneratorTest do
  use ExUnit.Case
  use Membrane.Pipeline

  import Membrane.Testing.Assertions

  alias Membrane.{Buffer, BlankVideoGenerator}
  alias Membrane.Caps.Video.Raw
  alias Membrane.Testing.{Pipeline, Sink}

  test "Blank Video Generator should work with buffers as demand unit for all allowed caps" do
    caps_i420 = %Raw{
      format: :I420,
      height: 720,
      width: 1280,
      framerate: {1, 1},
      aligned: true
    }

    caps_i422 = %Raw{caps_i420 | format: :I422}

    test_for_caps(caps_i420)
    test_for_caps(caps_i422)
  end

  defp test_for_caps(caps) do
    duration = Membrane.Time.seconds(3)

    elements = [
      generator: %BlankVideoGenerator{caps: caps, duration: duration},
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

    assert_sink_buffer(pid, :sink, %Buffer{payload: _payload})
    assert_sink_buffer(pid, :sink, %Buffer{payload: _payload})
    assert_sink_buffer(pid, :sink, %Buffer{payload: _payload})

    assert_end_of_stream(pid, :sink, :input, 5_000)
    Pipeline.stop_and_terminate(pid, blocking?: true)
  end
end
