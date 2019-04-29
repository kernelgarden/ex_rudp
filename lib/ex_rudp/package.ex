defmodule ExRudp.Package do
  defstruct buf: <<>>

  @spec new(binary()) :: ExRudp.Package.t()
  def new(buf \\ <<>>) do
    %__MODULE__{buf: buf}
  end
end
