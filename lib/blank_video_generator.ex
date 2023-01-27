defmodule Membrane.BlankVideoGenerator do
  @moduledoc """
  Element responsible for generating black screen as raw video.
  """

  use Membrane.Source

  alias Membrane.RawVideo
  alias Membrane.{Buffer, Time}

  def_options duration: [
                spec: Time.t(),
                description: "Duration of the output"
              ],
              stream_format: [
                spec: RawVideo.t(),
                description: "Video format of the output"
              ]

  def_output_pad :output,
    accepted_format:
      %RawVideo{pixel_format: pixel_format, aligned: true} when pixel_format in [:I420, :I422],
    mode: :pull,
    availability: :always

  @impl true
  def handle_init(_context, opts) do
    cond do
      not stream_format_supported?(opts.stream_format) ->
        raise """
        Cannot initialize generator, passed stream_format are not supported.
        """

      not correct_dimensions?(opts.stream_format) ->
        raise """
        Cannot initialize generator, the size of frame specified by stream_format doesn't pass format requirements.
        """

      true ->
        %RawVideo{framerate: {frames, seconds}} = opts.stream_format

        state =
          opts
          |> Map.from_struct()
          |> Map.put(:current_ts, Ratio.new(0, frames))
          |> Map.put(:frame, blank_frame(opts.stream_format))
          |> Map.put(:ts_increment, Ratio.new(seconds |> Time.seconds(), frames))

        {[], state}
    end
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    case get_buffers(size, state) do
      {buffers, state} -> {[buffer: {:output, buffers}], state}
      {:eos, buffers, state} -> {[buffer: {:output, buffers}, end_of_stream: :output], state}
    end
  end

  @impl true
  def handle_playing(_context, %{stream_format: stream_format} = state) do
    {[stream_format: {:output, stream_format}], state}
  end

  defp stream_format_supported?(%RawVideo{pixel_format: pixel_format, aligned: true})
       when pixel_format in [:I420, :I422],
       do: true

  defp stream_format_supported?(_stream_format), do: false

  defp correct_dimensions?(%RawVideo{pixel_format: :I420, width: width, height: height}) do
    rem(height, 2) == 0 && rem(width, 2) == 0
  end

  defp correct_dimensions?(%RawVideo{pixel_format: :I422, width: width}) do
    rem(width, 2) == 0
  end

  defp get_buffers(size, state, acc \\ [])
  defp get_buffers(0, state, acc), do: {Enum.reverse(acc), state}

  defp get_buffers(size, %{duration: duration, frame: frame} = state, acc) do
    {ts, new_state} = get_timestamp(state)

    if ts < duration do
      buffer = %Buffer{payload: frame, pts: ts}
      get_buffers(size - 1, new_state, [buffer | acc])
    else
      {:eos, Enum.reverse(acc), state}
    end
  end

  defp blank_frame(%RawVideo{pixel_format: :I420, width: width, height: height}) do
    :binary.copy(<<16>>, height * width) <>
      :binary.copy(<<128>>, div(height * width, 2))
  end

  defp blank_frame(%RawVideo{pixel_format: :I422, width: width, height: height}) do
    :binary.copy(<<16>>, height * width) <>
      :binary.copy(<<128>>, height * width)
  end

  defp get_timestamp(%{current_ts: current_ts, ts_increment: ts_increment} = state) do
    use Ratio

    new_ts = current_ts + ts_increment
    result_ts = current_ts |> Ratio.trunc()
    state = %{state | current_ts: new_ts}
    {result_ts, state}
  end
end
