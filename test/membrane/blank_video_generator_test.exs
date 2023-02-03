defmodule Membrane.BlankVideoGeneratorTest do
  use ExUnit.Case, async: true
  use Membrane.Pipeline

  import Membrane.Testing.Assertions
  import Membrane.ChildrenSpec

  alias Membrane.{BlankVideoGenerator, Buffer, RawVideo}
  alias Membrane.H264.FFmpeg.Encoder
  alias Membrane.Testing.{Pipeline, Sink}

  @stream_format_i420 %RawVideo{
    pixel_format: :I420,
    height: 720,
    width: 1280,
    framerate: {1, 1},
    aligned: true
  }
  @stream_format_i422 %RawVideo{@stream_format_i420 | pixel_format: :I422}

  describe "I420 format" do
    test "buffer generation" do
      test_for_stream_format(@stream_format_i420)
    end

    test "encoding generated buffers to H264" do
      test_h264(@stream_format_i420)
    end
  end

  describe "I422 format" do
    test "buffer generation" do
      test_for_stream_format(@stream_format_i422)
    end

    test "encoding generated buffers to H264" do
      test_h264(@stream_format_i422)
    end
  end

  defp test_for_stream_format(stream_format) do
    duration = Membrane.Time.seconds(3)

    structure =
      child(:generator, %BlankVideoGenerator{stream_format: stream_format, duration: duration})
      |> child(:sink, Sink)

    pipeline = Pipeline.start_link_supervised!(structure: structure)

    assert_start_of_stream(pipeline, :sink)
    assert_sink_stream_format(pipeline, :sink, stream_format)

    assert_sink_buffer(pipeline, :sink, %Buffer{payload: payload_1, pts: pts_1})
    assert_sink_buffer(pipeline, :sink, %Buffer{payload: payload_2, pts: pts_2})
    assert_sink_buffer(pipeline, :sink, %Buffer{payload: payload_3, pts: pts_3})

    assert pts_1 == 0
    assert pts_2 == Membrane.Time.seconds(1)
    assert pts_3 == Membrane.Time.seconds(2)

    blank_video = payload_1 <> payload_2 <> payload_3
    {:ok, size} = RawVideo.frame_size(stream_format)
    assert byte_size(blank_video) == 3 * size

    assert_end_of_stream(pipeline, :sink, :input, 5_000)
    Pipeline.terminate(pipeline, blocking?: true)
  end

  defp test_h264(stream_format) do
    duration = Membrane.Time.seconds(10)

    structure =
      child(:generator, %BlankVideoGenerator{stream_format: stream_format, duration: duration})
      |> via_in(:input, auto_demand_size: 10)
      |> child(:encoder, Encoder)
      |> child(:sink, Sink)

    pipeline = Pipeline.start_link_supervised!(structure: structure)

    assert_start_of_stream(pipeline, :sink)
    assert_end_of_stream(pipeline, :sink, :input, 5_000)
    Pipeline.terminate(pipeline, blocking?: true)
  end
end
