defmodule ExRudp.Message do
  defstruct buf: <<>>, id: 0, tick: 0

  @spec new() :: ExRudp.Message.t()
  def new(), do: %__MODULE__{}

  @spec new(binary(), integer(), integer()) :: ExRudp.Message.t()
  def new(buf, id, tick \\ 0) do
    %__MODULE__{buf: buf, id: id, tick: tick}
  end
end
