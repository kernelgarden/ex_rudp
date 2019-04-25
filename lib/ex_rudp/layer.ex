defmodule ExRudp.Layer do
  alias ExRudp.Package
  alias ExRudp.Package.Buf, as: PB
  alias ExRudp.Message
  alias ExRudp.Message.Queue, as: MQ

  defstruct recv_queue: nil,
            recv_skip: %{},
            recv_id_min: 0,
            recv_id_max: 0,
            send_queue: nil,
            send_history: nil,
            send_id: 0,
            req_send_again: [],
            add_send_again: [],
            corrpt: 0,
            current_tick: 0,
            last_recv_tick: 0,
            last_expired_tick: 0,
            last_send_delay_tick: 0

  @spec new() :: ExRudp.Layer.t()
  def new(), do: %__MODULE__{}

  @spec recv(__MODULE__.t()) ::
          {:ok, binary(), __MODULE__.t()} | {ExRudp.error(), __MODULE__.t()}
  def recv(%{__struct__: __MODULE__, corrupt: corrupt} = layer) do
    error_nil = ExRudp.error_nil()

    case corrupt == error_nil do
      true ->
        do_recv(layer)

      false ->
        {{:error, corrupt}, layer}
    end
  end

  defp do_recv(layer) do
    case MQ.pop(layer.recv_queue, layer.recv_id_min) do
      {:error, _} ->
        {:ok, 0, nil}

      {:ok, {new_recv_queue, message}} ->
        layer = put_in(layer.recv_queue, new_recv_queue)
        layer = put_in(layer.recv_id_min, layer.recv_id_min + 1)
        {:ok, message.buf, layer}
    end
  end

  @spec send(__MODULE__.t(), binary()) ::
          {:ok, integer(), __MODULE__.t()} | {ExRudp.error(), __MODULE__.t()}
  def send(%{__struct__: __MODULE__, corrupt: corrupt} = layer, data) do
    error_nil = ExRudp.error_nil()

    case corrupt == error_nil do
      true ->
        do_send(layer, data)

      false ->
        {{:error, corrupt}, layer}
    end
  end

  defp do_send(layer, data) do
    size = byte_size(data)
    max_package = ExRudp.max_package()

    case size > max_package do
      true ->
        {:ok, 0, layer}

      false ->
        new_message = Message.new(data, layer.send_id, layer.current_tick)
        layer = put_in(layer.send_id, layer.send_id + 1)
        layer = put_in(layer.send_queue, MQ.push(layer.send_queue, new_message))

        {:ok, size, layer}
    end
  end

  @spec update(__MODULE__.t(), integer()) ::
          {:ok, __MODULE__.t(), Package.t()} | {:error, __MODULE__.t()}
  def update(%{__struct__: __MODULE__, corrupt: corrupt} = layer, tick) do
    error_nil = ExRudp.error_nil()

    case corrupt == error_nil do
      true ->
        do_update(layer, tick)

      false ->
        {:error, layer}
    end
  end

  defp do_update(layer, tick) do
    put_in(layer.current_tick, layer.current_tick + tick)
    |> check_expiration()
    |> check_corruption()
    |> check_delay()
    |> case do
      {:ok, layer} ->
        :noop

      {:error, layer} ->
        :noop
    end

    # todo: add make output package
    output(layer)

    {:ok, layer, nil}
  end

  defp check_expiration(layer) do
    if layer.current_tick >= layer.last_exipired_tick + ExRudp.expired_tick() do
      put_in(layer.last_expired_tick, layer.current_tick)
      |> clear_send_expiration()
    else
      # do not anything
      layer
    end
  end

  defp check_corruption(layer) do
    if layer.current_tick >= layer.last_recv_tick + ExRudp.corrupt_tick() do
      put_in(layer.corrupt, ExRudp.error_corrupt())
    else
      layer
    end
  end

  defp check_delay(layer) do
    if layer.current_tick >= layer.last_send_delay_tick + ExRudp.send_delay_tick() do
      {:ok, put_in(layer.last_send_delay_tick, layer.current_tick)}
    else
      {:error, layer}
    end
  end

  defp clear_send_expiration(layer) do
    new_send_history =
      layer.send_history
      |> Enum.drop_while(fn message -> message.tick < layer.last_expred_tick end)

    put_in(layer.send_history, new_send_history)
  end

  defp output(layer) do
    {layer, package_buf} =
      {layer, PB.new()}
      |> request_missing()
      |> reply_request()
      |> send_message()

    {layer, PB.generate_new_package(package_buf)}
  end

  defp request_missing({%{req_send_again: []} = layer, package_buf}) do
    {layer, package_buf}
  end

  defp request_missing({%{req_send_again: [head | tail]} = layer, package_buf}) do
    layer = put_in(layer.req_send_again, tail)

    {min, max} = head
    package_buf = PB.pack_request(package_buf, min, max, ExRudp.type_request())

    {layer, package_buf}
  end

  defp reply_request({layer, package_buf}) do
    {layer, package_buf}
  end

  defp send_message({layer, package_buf}) do
    {layer, package_buf}
  end
end
