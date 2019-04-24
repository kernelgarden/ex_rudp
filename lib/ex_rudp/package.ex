defmodule ExRudp.Package do
  defstruct next_ref: nil, buf: <<>>

  @spec new(binary()) :: ExRudp.Package.t()
  def new(buf \\ <<>>) do
    %__MODULE__{buf: buf}
  end
end
