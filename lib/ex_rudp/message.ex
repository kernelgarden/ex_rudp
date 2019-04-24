defmodule ExRudp.Message do
  defstruct next: nil, buf: <<>>, id: 0, tick: 0
end
