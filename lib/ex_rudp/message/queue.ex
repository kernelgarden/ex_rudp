defmodule ExRudp.Message.Queue do

  alias ExRudp.Message

  defstruct internal_queue: [], num: 0

  @spec pop(__MODULE__.t(), integer()) :: {:ok, {__MODULE__.t(), Message.t()}}
  def pop(queue, id) do
    queue
  end

  @spec push(__MODULE__.t(), Message.t()) :: __MODULE__.t()
  def push(queue, message) do
    queue = put_in(queue.internal_queue, [message | queue.internal_queue])
    queue = put_in(queue.num, queue.num + 1)
    queue
  end

end
