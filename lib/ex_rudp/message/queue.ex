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

defimpl Enumerable, for: ExRudp.Message.Queue do
  def count(%{__struct: __MODULE__, num: num} = _queue), do: {:ok, num}

  def member?(%{__struct__: __MODULE__, internal_queue: internal_queue} = _queue, elem) do
    case Enum.member?(internal_queue, elem) do
      true ->
        {:ok, true}

      false ->
        {:ok, false}
    end
  end

  def reduce(_queue, {:halt, acc}, _fun), do: {:halted, acc}

  def reduce(queue, {:suspend, acc}, fun) do
    {:suspended, acc, &reduce(queue, &1, fun)}
  end

  def reduce(
        %{__struct__: __MODULE__, internal_queue: internal_queue} = _queue,
        {:cont, acc},
        _fun
      )
      when internal_queue == [] do
    {:done, acc}
  end

  def reduce(
        %{__struct__: __MODULE__, internal_queue: [head | tail], num: num} = queue,
        {:cont, acc},
        fun
      ) do
    queue = put_in(queue.internal_queue, tail)
    queue = put_in(queue.num, num - 1)
    reduce(queue, fun.(head, acc), fun)
  end

  def slice(%{__struct__: __MODULE__, internal_queue: internal_queue, num: num} = _queue) do
    {:ok, num, &slicing_fun(internal_queue, &1, &2)}
  end

  defp slicing_fun(queue, start, length) do
    Enum.slice(queue, start, length)
  end
end
