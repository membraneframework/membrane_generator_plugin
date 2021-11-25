defmodule Membrane.BlankVideoGenerator do
  @moduledoc """
  Element responsible for generating black screen as raw video.
  """

  use Membrane.Source

  alias Membrane.{Buffer, Time}
  alias Membrane.Caps.Matcher
  alias Membrane.Caps.Video.Raw

  @supported_caps {Raw, format: Matcher.one_of([:I420, :I422]), aligned: true}

  def_options duration: [
                type: :integer,
                spec: Time.t(),
                description: "Duration of the output"
              ],
              caps: [
                type: :struct,
                spec: Raw.t(),
                description: "Video format of the output"
              ]

  def_output_pad :output,
    caps: @supported_caps,
    mode: :pull,
    availability: :always

  @impl true
  def handle_init(opts) do
    %Raw{framerate: {frames, seconds}} = opts.caps

    if caps_correct?(opts.caps) do
      state =
        opts
        |> Map.from_struct()
        |> Map.put(:current_ts, Ratio.new(0, frames))
        |> Map.put(:frame, blank_frame(opts.caps))
        |> Map.put(:ts_increment, Ratio.new(seconds |> Time.seconds(), frames))

      {:ok, state}
    else
      {:error, :caps_not_supported}
    end
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    with {buffers, state} <- get_buffers(size, state) do
      {{:ok, buffer: {:output, buffers}}, state}
    else
      {:eos, buffers, state} -> {{:ok, buffer: {:output, buffers}, end_of_stream: :output}, state}
    end
  end

  @impl true
  def handle_prepared_to_playing(_context, %{caps: caps} = state) do
    {{:ok, caps: {:output, caps}}, state}
  end

  defp caps_correct?(caps), do: Matcher.match?(@supported_caps, caps) && do_caps_correct?(caps)

  defp do_caps_correct?(%Raw{format: :I420, width: width, height: height}) do
    rem(height, 2) == 0 && rem(width, 2) == 0
  end

  defp do_caps_correct?(%Raw{format: :I422, width: width}) do
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

  defp blank_frame(%Raw{format: :I420, width: width, height: height}) do
    :binary.copy(<<16>>, height * width) <>
      :binary.copy(<<128>>, div(height * width, 2))
  end

  defp blank_frame(%Raw{format: :I422, width: width, height: height}) do
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
