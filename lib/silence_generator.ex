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
    do_handle_demand(1, time, state)
  end

  def handle_demand(:output, buffers, :buffers, _ctx, state) do
    %{caps: caps, frames_per_buffer: frames_per_buffer} = state

    time = RawAudio.frames_to_time(frames_per_buffer, caps)
    do_handle_demand(buffers, time, state)
  end

  defp do_handle_demand(buffers_number, time, state, buffers \\ [])

  defp do_handle_demand(
         buffers_number,
         time,
         %{caps: caps, duration: :infinity, passed_time: passed_time} = state,
         buffers
       ) do
    buffer = %Buffer{payload: RawAudio.silence(caps, time), pts: passed_time}
    buffers = [buffer | buffers]
    state = %{state | passed_time: passed_time + time}

    if buffers_number == 1 do
      {{:ok, buffer: {:output, Enum.reverse(buffers)}}, state}
    else
      do_handle_demand(buffers_number - 1, time, state, buffers)
    end
  end

  defp do_handle_demand(
         buffers_number,
         time,
         %{caps: caps, duration: duration, passed_time: passed_time} = state,
         buffers
       ) do
    {buffer, state} =
      if passed_time + time < duration do
        {%Buffer{payload: RawAudio.silence(caps, time), pts: passed_time},
         %{state | passed_time: passed_time + time}}
      else
        {%Buffer{payload: RawAudio.silence(caps, duration - passed_time), pts: passed_time},
         %{state | passed_time: duration}}
      end

    buffers = [buffer | buffers]

    case {state.passed_time, buffers_number} do
      {^duration, _} ->
        {{:ok, buffer: {:output, Enum.reverse(buffers)}, end_of_stream: :output}, state}

      {_, 1} ->
        {{:ok, buffer: {:output, Enum.reverse(buffers)}}, state}

      _else ->
        do_handle_demand(buffers_number - 1, time, state, buffers)
    end
  end
end
