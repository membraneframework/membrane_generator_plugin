defmodule Membrane.SilenceGenerator do
  @moduledoc """
  Element responsible for generating silence as raw audio.
  """

  use Membrane.Source

  alias Membrane.{Buffer, Time}
  alias Membrane.Caps.Audio.Raw

  def_options caps: [
                type: :struct,
                spec: Raw.t(),
                description: "Audio caps of generated samples (`t:Membrane.Caps.Audio.Raw.t/0`)"
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

  def_output_pad :output, caps: Raw

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
    time = Raw.bytes_to_time(size, caps)
    do_handle_demand(time, state)
  end

  def handle_demand(:output, buffers, :buffers, _ctx, state) do
    %{caps: caps, frames_per_buffer: frames_per_buffer} = state

    time = buffers * Raw.frames_to_time(frames_per_buffer, caps)
    do_handle_demand(time, state)
  end

  defp do_handle_demand(time, %{caps: caps, duration: :infinity} = state) do
    buffer = %Buffer{payload: Raw.sound_of_silence(caps, time)}
    {{:ok, buffer: {:output, buffer}}, state}
  end

  defp do_handle_demand(time, state) do
    %{caps: caps, duration: duration, passed_time: passed_time} = state

    if passed_time + time < duration do
      buffer = %Buffer{payload: Raw.sound_of_silence(caps, time)}
      state = %{state | passed_time: passed_time + time}

      {{:ok, buffer: {:output, buffer}}, state}
    else
      buffer = %Buffer{payload: Raw.sound_of_silence(caps, duration - passed_time)}
      state = %{state | passed_time: duration}

      {{:ok, buffer: {:output, buffer}, end_of_stream: :output}, state}
    end
  end
end
