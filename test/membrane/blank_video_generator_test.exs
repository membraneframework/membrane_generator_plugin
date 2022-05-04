defmodule Membrane.BlankVideoGeneratorTest do
  use ExUnit.Case, async: true
  use Membrane.Pipeline

  import Membrane.Testing.Assertions

  alias Membrane.{BlankVideoGenerator, Buffer, RawVideo}
  alias Membrane.H264.FFmpeg.Encoder
  alias Membrane.Testing.{Pipeline, Sink}

  @caps_i420 %RawVideo{
    pixel_format: :I420,
    height: 720,
    width: 1280,
    framerate: {1, 1},
    aligned: true
  }
  @caps_i422 %RawVideo{@caps_i420 | pixel_format: :I422}

  describe "I420 format" do
    test "buffer generation" do
      test_for_caps(@caps_i420)
    end

    test "encoding generated buffers to H264" do
      test_h264(@caps_i420)
    end
  end

  describe "I422 format" do
    test "buffer generation" do
      test_for_caps(@caps_i422)
    end

    test "encoding generated buffers to H264" do
      test_h264(@caps_i422)
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
    on_exit(fn -> Pipeline.terminate(pid, blocking: true) end)

    assert_start_of_stream(pid, :sink)
    assert_sink_caps(pid, :sink, caps)

    assert_sink_buffer(pid, :sink, %Buffer{payload: payload_1, pts: pts_1})
    assert_sink_buffer(pid, :sink, %Buffer{payload: payload_2, pts: pts_2})
    assert_sink_buffer(pid, :sink, %Buffer{payload: payload_3, pts: pts_3})

    assert pts_1 == 0
    assert pts_2 == Membrane.Time.seconds(1)
    assert pts_3 == Membrane.Time.seconds(2)

    blank_video = payload_1 <> payload_2 <> payload_3
    {:ok, size} = RawVideo.frame_size(caps)
    assert byte_size(blank_video) == 3 * size

    assert_end_of_stream(pid, :sink, :input, 5_000)
    Pipeline.terminate(pid, blocking?: true)
  end

  defp test_h264(caps) do
    duration = Membrane.Time.seconds(10)

    elements = [
      generator: %BlankVideoGenerator{caps: caps, duration: duration},
      encoder: Encoder,
      sink: Sink
    ]

    links = [
      link(:generator)
      |> to(:encoder)
      |> to(:sink)
    ]

    pipeline_options = %Pipeline.Options{elements: elements, links: links}
    assert {:ok, pid} = Pipeline.start_link(pipeline_options)
    on_exit(fn -> Pipeline.terminate(pid, blocking: true) end)

    assert_start_of_stream(pid, :sink)
    assert_end_of_stream(pid, :sink, :input, 5_000)
    Pipeline.terminate(pid, blocking?: true)
  end
end
