defmodule Membrane.SilenceGenerator do
  @moduledoc """
  Element responsible for generating silence as raw audio.
  """

  use Membrane.Source

  alias Membrane.{Buffer, Time}
  alias Membrane.RawAudio

  def_options stream_format: [
                spec: RawAudio.t(),
                description: "Audio stream format of generated samples (`RawAudio.t/0`)"
              ],
              duration: [
                spec: Time.t() | :infinity,
                description: "Duration of the generated silent samples"
              ],
              frames_per_buffer: [
                spec: pos_integer(),
                description: """
                Assumed number of raw audio frames in each buffer.
                Used when converting demand from buffers into bytes.
                """,
                default: 2048
              ]

  def_output_pad :output, accepted_format: RawAudio

  @impl true
  def handle_init(_ctx, opts) do
    state =
      opts
      |> Map.from_struct()
      |> Map.put(:passed_time, 0)

    {[], state}
  end

  @impl true
  def handle_playing(_context, %{stream_format: stream_format} = state) do
    {[stream_format: {:output, stream_format}], state}
  end

  @impl true
  def handle_demand(:output, size, :bytes, _ctx, %{stream_format: stream_format} = state) do
    time = RawAudio.bytes_to_time(size, stream_format)
    do_handle_demand(time, time, state)
  end

  def handle_demand(:output, buffers, :buffers, _ctx, state) do
    %{stream_format: stream_format, frames_per_buffer: frames_per_buffer} = state

    time = RawAudio.frames_to_time(frames_per_buffer, stream_format)
    do_handle_demand(time * buffers, time, state)
  end

  defp do_handle_demand(
         total_time,
         chunk_time,
         %{stream_format: stream_format, duration: :infinity, passed_time: passed_time} = state
       ) do
    buffers = generate_buffers(passed_time, chunk_time, total_time, stream_format)
    state = %{state | passed_time: passed_time + total_time}

    {[buffer: {:output, buffers}], state}
  end

  defp do_handle_demand(
         total_time,
         chunk_time,
         %{stream_format: stream_format, duration: duration, passed_time: passed_time} = state
       ) do
    total_time = min(total_time, duration - passed_time)
    buffers = generate_buffers(passed_time, chunk_time, total_time, stream_format)
    state = %{state | passed_time: passed_time + total_time}

    if state.passed_time == duration,
      do: {[buffer: {:output, buffers}, end_of_stream: :output], state},
      else: {[buffer: {:output, buffers}], state}
  end

  defp generate_buffers(start_time, chunk_time, total_time, stream_format, buffers \\ [])

  defp generate_buffers(_start_time, _chunk_time, 0, _stream_format, buffers),
    do: Enum.reverse(buffers)

  defp generate_buffers(start_time, chunk_time, total_time, stream_format, buffers) do
    buffer_time = min(total_time, chunk_time)

    buffer = %Buffer{
      payload: RawAudio.silence(stream_format, buffer_time),
      pts: start_time
    }

    generate_buffers(
      start_time + buffer_time,
      chunk_time,
      total_time - buffer_time,
      stream_format,
      [
        buffer | buffers
      ]
    )
  end
end
