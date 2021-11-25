defmodule Membrane.BlankVideoGeneratorTest do
  use ExUnit.Case, async: true
  use Membrane.Pipeline

  import Membrane.Testing.Assertions

  alias Membrane.{Buffer, BlankVideoGenerator}
  alias Membrane.Caps.Video.Raw
  alias Membrane.Testing.{Pipeline, Sink}

  @caps_i420 %Raw{
    format: :I420,
    height: 720,
    width: 1280,
    framerate: {1, 1},
    aligned: true
  }

  describe "Blank Video Generator should work with buffers as demand unit for caps" do
    test "with I420 format" do
      test_for_caps(@caps_i420)
    end

    test "with I422 format" do
      caps_i422 = %Raw{@caps_i420 | format: :I422}

      test_for_caps(caps_i422)
    end
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
    assert_sink_caps(pid, :sink, caps)

    assert_sink_buffer(pid, :sink, %Buffer{payload: payload_1, pts: pts_1})
    assert_sink_buffer(pid, :sink, %Buffer{payload: payload_2, pts: pts_2})
    assert_sink_buffer(pid, :sink, %Buffer{payload: payload_3, pts: pts_3})

    assert pts_1 == 0
    assert pts_2 == Membrane.Time.seconds(1)
    assert pts_3 == Membrane.Time.seconds(2)

    blank_video = payload_1 <> payload_2 <> payload_3
    {:ok, size} = Raw.frame_size(caps)
    assert byte_size(blank_video) == 3 * size

    assert_end_of_stream(pid, :sink, :input, 5_000)
    Pipeline.stop_and_terminate(pid, blocking?: true)
  end
end
