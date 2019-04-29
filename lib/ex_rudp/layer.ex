defmodule ExRudp.Layer do
  require Logger

  alias ExRudp.Package
  alias ExRudp.Package.Buf, as: PB
  alias ExRudp.Message
  alias ExRudp.Message.Queue, as: MQ
  alias ExRudp.BinaryUtil

  defstruct recv_queue: MQ.new(),
            recv_skip: %{},
            recv_id_min: 0,
            recv_id_max: 0,
            send_queue: MQ.new(),
            send_history: MQ.new(),
            send_id: 0,
            req_send_again: [],
            add_send_again: [],
            corrupt: 0,
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
        {layer, package} = output(layer)
        {:ok, layer, package}

      {:error, layer} ->
        {:error, layer}
    end
  end

  defp check_expiration(layer) do
    if layer.current_tick >= layer.last_expired_tick + ExRudp.expired_tick() do
      put_in(layer.last_expired_tick, layer.current_tick)
      |> clear_send_expiration()
    else
      Logger.debug(fn -> "check expiration=> left: #{inspect layer.current_tick}, right: #{inspect layer.last_expired_tick + ExRudp.expired_tick()}" end)
      layer
    end
  end

  defp check_corruption(layer) do
    if layer.current_tick >= layer.last_recv_tick + ExRudp.corrupt_tick() do
      put_in(layer.corrupt, ExRudp.error_corrupt())
    else
      Logger.debug(fn -> "check corruption=> left: #{inspect layer.current_tick}, right: #{inspect layer.last_recv_tick + ExRudp.corrupt_tick()}" end)
      layer
    end
  end

  defp check_delay(layer) do
    if layer.current_tick >= layer.last_send_delay_tick + ExRudp.send_delay_tick() do
      {:ok, put_in(layer.last_send_delay_tick, layer.current_tick)}
    else
      Logger.debug(fn -> "check delay=> left: #{inspect layer.current_tick}, right: #{inspect layer.last_send_delay_tick + ExRudp.send_delay_tick()}" end)
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

  defp request_missing({%{req_send_again: []} = layer, package_buf}), do: {layer, package_buf}

  defp request_missing({%{req_send_again: [head | tail]} = layer, package_buf}) do
    layer = put_in(layer.req_send_again, tail)

    {min, max} = head
    package_buf = PB.pack_request(package_buf, min, max, ExRudp.type_request())

    request_missing({layer, package_buf})
  end

  defp reply_request({%{add_send_again: []} = layer, package_buf}), do: {layer, package_buf}

  defp reply_request({%{add_send_again: [head | tail]} = layer, package_buf}) do
    layer = put_in(layer.add_send_again, tail)

    {min, max} = head
    package_buf = do_reply_request(layer.send_history, package_buf, min, max)

    {layer, package_buf}
  end

  defp do_reply_request([head | _tail] = send_history, package_buf, min, max) do
    if max < head.id do
      PB.pack_request(package_buf, min, max, ExRudp.type_missing())
    else
      process_send_history(package_buf, send_history, min, max, 0)
    end
  end

  defp process_send_history(package_buf, [], min, _max, start) do
    case min < start do
      true -> handle_missing(package_buf, min, start - 1)
      false -> package_buf
    end
  end

  defp process_send_history(package_buf, [head | tail] = _send_history, min, max, start) do
    if min <= head.id do
      package_buf = PB.pack_message(package_buf, head)
      start = if start == 0, do: head.id, else: start
      process_send_history(package_buf, tail, min, max, start)
    else
      # jump direct
      process_send_history(package_buf, [], min, max, start)
    end
  end

  defp handle_missing(package_buf, min, max) do
    PB.pack_request(package_buf, min, max, ExRudp.type_missing())
  end

  defp send_message({layer, package_buf}) do
    package_buf =
      layer.send_queue
      |> Enum.reduce(package_buf, fn message, acc_package_buf ->
        PB.pack_message(acc_package_buf, message)
      end)

    send_list =
      layer.send_queue
      |> Enum.into([], fn message -> message end)

    # append send_queue to send_history
    layer = put_in(layer.send_history, MQ.push_list(layer.send_history, send_list))

    # reset send_history
    layer = put_in(layer.send_queue, MQ.reset(layer.send_queue))

    {layer, package_buf}
  end

  defp get_id(max, n1, n2) do
    id = n1 * 256 + n2

    filter = BinaryUtil.bin_and(max, BinaryUtil.bin_not(0xFFFF))
    id = BinaryUtil.bin_or(id, filter)

    cond do
      id < max - 0x8000 -> id + 0x10000
      id > max + 0x8000 -> id - 0x10000
      true -> id
    end
  end

  @spec input(__MODULE__.t(), binary()) :: __MODULE__.t()
  def input(layer, <<>>) do
    layer
  end

  def input(layer, data) do
    layer = put_in(layer.last_recv_tick, layer.current_tick)

    {layer, remain} = do_input(data, layer)
    check_missing(layer, false)
    {layer, remain}
  end

  defp do_input(<<>>, layer), do: {layer, <<>>}

  defp do_input(
         <<len::8, rest::binary>> = data,
         layer
       ) do
    cond do
      len > 127 and byte_size(data) <= 1 ->
        layer = put_in(layer.corrupt, ExRudp.error_msg_size())
        {layer, data}

      len > 127 ->
        <<bts1::8, rest::binary>> = rest
        len = BinaryUtil.bin_and(len * 256 + bts1, 0x7FFF)

        case process_header(rest, layer, len) do
          {:stop, layer, remain} ->
            {layer, remain}

          {:cont, layer, remain} ->
            do_input(remain, layer)
        end

      true ->
        case process_header(rest, layer, len) do
          {:stop, layer, remain} ->
            {layer, remain}

          {:cont, layer, remain} ->
            do_input(remain, layer)
        end
    end
  end

  defp do_input(<<remain::binary>>, layer) do
    Logger.error("[do_input] Something wrong")
    {layer, remain}
  end

  # handle type ping
  defp process_header(<<data::binary>>, layer, 0) do
    {:cont, check_missing(layer, false), data}
  end

  # handle type eof
  defp process_header(<<data::binary>>, layer, 1) do
    layer = put_in(layer.corrupt, ExRudp.error_eof())
    {:cont, layer, data}
  end

  # handle type corrupt
  defp process_header(<<data::binary>>, layer, 2) do
    layer = put_in(layer.corrupt, ExRudp.error_remote_eof())
    {:stop, layer, data}
  end

  # handle type request
  defp process_header(<<data::binary>>, layer, 3) do
    size = byte_size(data)

    if size < 4 do
      layer = put_in(layer.corrupt, ExRudp.error_msg_size())
      {:stop, layer, data}
    else
      <<bts1::8, bts2::8, bts3::8, bts4::8, remain::binary>> = data
      first = get_id(layer.send_id, bts1, bts2)
      second = get_id(layer.send_id, bts3, bts4)
      layer = put_in(layer.add_send_again, layer.add_send_again ++ [{first, second}])
      {:cont, layer, remain}
    end
  end

  # handle type missing
  defp process_header(<<data::binary>>, layer, 4) do
    size = byte_size(data)

    if size < 4 do
      layer = put_in(layer.corrupt, ExRudp.error_msg_size())
      {:stop, layer, data}
    else
      <<bts1::8, bts2::8, bts3::8, bts4::8, remain::binary>> = data
      first = get_id(layer.recv_id_max, bts1, bts2)
      second = get_id(layer.recv_id_max, bts3, bts4)
      layer = add_missing(layer, first, second)
      {:cont, layer, remain}
    end
  end

  # handle type normal
  defp process_header(<<data::binary>>, layer, len) do
    case byte_size(data) < len + 2 do
      true ->
        layer = put_in(layer.corrupt, ExRudp.error_msg_size())
        {:stop, layer, data}

      false ->
        <<bts1::8, bts2::8, message::binary-size(len), remain::binary>> = data

        id = get_id(layer.recv_id_max, bts1, bts2)
        layer = insert_message(layer, id, message)

        {:cont, layer, remain}
    end
  end

  defp insert_message(%{__struct__: __MODULE__, recv_id_min: recv_id_min} = layer, id, _bin)
       when id < recv_id_min do
    layer
  end

  defp insert_message(layer, id, bin) do
    layer = put_in(layer.recv_skip, Map.delete(layer.recv_skip, id))

    layer =
      case id > layer.recv_id_max or MQ.is_empty?(layer.recv_queue) do
        true ->
          new_message = Message.new(bin, id)
          layer = put_in(layer.recv_queue, MQ.push(layer.recv_queue, new_message))
          layer = put_in(layer.recv_id_max, id)
          layer

        false ->
          new_message = Message.new(bin, id)

          layer =
            put_in(
              layer.recv_queue,
              MQ.insert_first(layer.recv_queue, new_message, fn m1, m2 ->
                m1.id > m2.id
              end)
            )

          layer
      end

    layer
  end

  defp add_missing(layer, min, max) do
    cond do
      max < layer.recv_id_min ->
        layer

      min > layer.recv_id_min ->
        layer

      true ->
        layer = put_in(layer.recv_id_min, max + 1)
        check_missing(layer, true)
    end
  end

  defp check_missing(layer, direct) do
    case Enum.at(layer.recv_queue, 0) do
      nil ->
        layer

      message ->
        if message.id > layer.recv_id_min do
          do_check_missing(layer, direct, message.id)
        else
          layer
        end
    end
  end

  defp do_check_missing(layer, direct, message_id) do
    nano = DateTime.to_unix(DateTime.utc_now(), :microsecond) * 1_000
    last = Map.get(layer.recv_skip, layer.recv_id_min)

    cond do
      !direct and last == 0 ->
        new_recv_skip = Map.put(layer.recv_skip, layer.recv_id_min, nano)
        put_in(layer.recv_skip, new_recv_skip)

      direct or last + ExRudp.missing_time() < nano ->
        new_recv_skip = Map.delete(layer.recv_skip, layer.recv_id_min)

        layer =
          put_in(layer.req_send_again, layer.req_send_again ++ [{layer.recv_id_min, message_id}])

        put_in(layer.recv_skip, new_recv_skip)

      true ->
        layer
    end
  end
end
