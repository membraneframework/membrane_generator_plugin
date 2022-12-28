defmodule Membrane.SilenceGenerator do
  @moduledoc """
  Element responsible for generating silence as raw audio.
  """

  use Membrane.Source

  alias Membrane.{Buffer, Time}
  alias Membrane.RawAudio

  def_options caps: [
                type: :struct,
                spec: RawAudio.t(),
                description:
                  "Audio caps of generated samples (`t:Membrane.Caps.Audio.RawAudio.t/0`)"
              ],
              duration: [
                type: :timeout,
                spec: Time.t() | :infinity,
                description: "Duration of the generated silent samples"
              ],
              frames_per_buffer: [
                type: :integer,
                spec: pos_integer(),
                description: """
                Assumed number of raw audio frames in each buffer.
                Used when converting demand from buffers into bytes.
                """,
                default: 2048
              ]

  def_output_pad :output, caps: RawAudio

  @impl true
  def handle_init(opts) do
    state =
      opts
      |> Map.from_struct()
      |> Map.put(:passed_time, 0)

    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_context, %{caps: caps} = state) do
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_demand(:output, size, :bytes, _ctx, %{caps: caps} = state) do
    time = RawAudio.bytes_to_time(size, caps)
    do_handle_demand(time, time, state)
  end

  def handle_demand(:output, buffers, :buffers, _ctx, state) do
    %{caps: caps, frames_per_buffer: frames_per_buffer} = state

    time = RawAudio.frames_to_time(frames_per_buffer, caps)
    do_handle_demand(time * buffers, time, state)
  end

  defp do_handle_demand(
         total_time,
         chunk_time,
         %{caps: caps, duration: :infinity, passed_time: passed_time} = state
       ) do
    buffers = generate_buffers(passed_time, chunk_time, total_time, caps)
    state = %{state | passed_time: passed_time + total_time}

    {{:ok, buffer: {:output, buffers}}, state}
  end

  defp do_handle_demand(
         total_time,
         chunk_time,
         %{caps: caps, duration: duration, passed_time: passed_time} = state
       ) do
    total_time = min(total_time, duration - passed_time)
    buffers = generate_buffers(passed_time, chunk_time, total_time, caps)
    state = %{state | passed_time: passed_time + total_time}

    if state.passed_time == duration,
      do: {{:ok, buffer: {:output, buffers}, end_of_stream: :output}, state},
      else: {{:ok, buffer: {:output, buffers}}, state}
  end

  defp generate_buffers(start_time, chunk_time, total_time, caps, buffers \\ [])
  defp generate_buffers(_start_time, _chunk_time, 0, _caps, buffers), do: Enum.reverse(buffers)

  defp generate_buffers(start_time, chunk_time, total_time, caps, buffers) do
    buffer_time = min(total_time, chunk_time)

    buffer = %Buffer{
      payload: RawAudio.silence(caps, buffer_time),
      pts: start_time
    }

    generate_buffers(start_time + buffer_time, chunk_time, total_time - buffer_time, caps, [
      buffer | buffers
    ])
  end
end
