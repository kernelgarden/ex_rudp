defmodule ExRudp.Layer.Process do
  use GenServer

  alias ExRudp.Layer

  def start_link(layer) do
    GenServer.start_link(__MODULE__, layer)
  end

  @impl true
  def init(layer) do
    {:ok, layer}
  end
end
