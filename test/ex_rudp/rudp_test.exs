defmodule ExRudp.RudpTest do
  use ExUnit.Case, async: true

  alias ExRudp.Layer

  test "rudp test" do
    layer = Layer.new()

    t1 = <<1, 2, 3, 4>>
    t2 = <<5, 6, 7, 8>>

    t3 =
      <<2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1,
        1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1,
        1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1,
        1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3,
        2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1,
        1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1,
        1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1,
        1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 1, 1, 1, 3,
        2, 1, 1, 1, 1, 1, 1, 3, 2, 1, 1, 1, 10, 11, 12, 13>>

    t4 = <<4, 3, 2, 1>>

    layer = send_helper(layer, t1)
    layer = send_helper(layer, t2)

    assert {:error, _} = Layer.update(layer, 0)

    assert {:ok, layer, package_buf} = Layer.update(layer, ExRudp.send_delay_tick())
    assert check_send_length(package_buf) == byte_size(t1) + 3 + byte_size(t2) + 3

    assert {:ok, layer, package_buf} = Layer.update(layer, ExRudp.send_delay_tick())
    assert package_buf != nil
    assert length(package_buf.list) == 0

    layer = send_helper(layer, t3)
    layer = send_helper(layer, t4)

    assert {:ok, layer, package_buf} = Layer.update(layer, ExRudp.send_delay_tick())
    # |> IO.inspect()
    assert check_send_length(package_buf) == byte_size(t3) + 4 + byte_size(t4) + 3

    IO.puts("=========================================================")

    tmp = <<ExRudp.type_request(), 0, 0, 0, 0, ExRudp.type_request(), 0, 3, 0, 3>>

    layer =
      Layer.input(layer, tmp)
      |> IO.inspect(label: "[Debug2] => ")

    assert {:ok, layer, package_buf} =
             Layer.update(layer, ExRudp.send_delay_tick())
             |> IO.inspect(label: "[Debug1] => ")

    assert check_send_length(package_buf) == byte_size(t1) + 3 + byte_size(t4) + 3
  end

  defp send_helper(layer, bin) do
    case Layer.send(layer, bin) do
      {:ok, size, layer} ->
        IO.puts("Send successful! size: #{inspect(size)}")
        layer

      {:error, reason} ->
        IO.puts("Send fail! reason: #{inspect(reason)}")
        layer
    end
  end

  defp check_send_length(package_buf) do
    package_buf
    |> Enum.reduce(0, fn package, acc ->
      acc + byte_size(package.buf)
    end)
  end
end
