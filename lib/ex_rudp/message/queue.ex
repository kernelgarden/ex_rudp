defmodule ExRudp.Message.Queue do
  alias ExRudp.Message

  defstruct internal_queue: [], num: 0

  @spec pop(__MODULE__.t(), integer()) ::
          {:ok, {__MODULE__.t(), Message.t()}}
          | {:error, :empty}
          | {:error, :not_matched}
  def pop(queue, id) do
    case Enum.at(queue.internal_queue, -1) do
      nil ->
        nil

      message ->
        do_pop(queue, id, message)
    end
  end

  defp do_pop(_queue, _id, message) when message == nil do
    {:error, :empty}
  end

  defp do_pop(queue, id, message) do
    case message.id >= 0 and message.id != id do
      true ->
        {:error, :not_matched}

      false ->
        queue = put_in(queue.num, queue.num - 1)

        queue =
          put_in(
            queue.internal_queue,
            List.delete_at(queue.internal_queue, -1)
          )

        {:ok, {queue, message}}
    end
  end

  @spec push(__MODULE__.t(), Message.t()) :: __MODULE__.t()
  def push(queue, message) do
    queue = put_in(queue.internal_queue, [message | queue.internal_queue])
    queue = put_in(queue.num, queue.num + 1)
    queue
  end
end
