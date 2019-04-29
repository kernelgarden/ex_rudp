defmodule ExRudp.Package.Buf do
  alias ExRudp
  alias ExRudp.Package
  alias ExRudp.Message
  alias ExRudp.BinaryUtil

  defstruct tmp: <<>>, seq: 0, list: []

  @spec new() :: ExRudp.Package.Buf.t()
  def new() do
    %__MODULE__{}
  end

  @spec generate_new_package(__MODULE__.t()) :: ExRudp.Package.t()
  def generate_new_package(package_buf) do
    do_generate_new_package(package_buf, byte_size(package_buf.tmp))
  end

  defp do_generate_new_package(package_buf, length) when length <= 0, do: package_buf

  defp do_generate_new_package(package_buf, _length) do
    new_package = Package.new(package_buf.tmp)

    package_buf = put_in(package_buf.tmp, <<>>)
    package_buf = put_in(package_buf.list, package_buf.list ++ [new_package])
    package_buf = put_in(package_buf.seq, package_buf.seq + 1)

    package_buf
  end

  @spec pack_request(__MODULE__.t(), integer(), integer(), integer()) :: __MODULE__.t()
  def pack_request(package_buf, min, max, tag) do
    general_package = ExRudp.general_package()

    case byte_size(package_buf.tmp) > general_package do
      true ->
        package_buf
        |> generate_new_package()
        |> do_pack_request(min, max, tag)

      false ->
        do_pack_request(package_buf, min, max, tag)
    end
  end

  defp do_pack_request(package_buf, min, max, tag) do
    package_buf = put_in(package_buf.tmp, BinaryUtil.append(tag, package_buf.tmp))

    package_buf =
      put_in(
        package_buf.tmp,
        min
        |> BinaryUtil.bin_and(0xFF00)
        |> BinaryUtil.bin_sr(8)
        |> BinaryUtil.append(package_buf.tmp)
      )

    package_buf =
      put_in(
        package_buf.tmp,
        min
        |> BinaryUtil.bin_and(0xFF)
        |> BinaryUtil.append(package_buf.tmp)
      )

    package_buf =
      put_in(
        package_buf.tmp,
        max
        |> BinaryUtil.bin_and(0xFF00)
        |> BinaryUtil.bin_sr(8)
        |> BinaryUtil.append(package_buf.tmp)
      )

    package_buf =
      put_in(
        package_buf.tmp,
        max
        |> BinaryUtil.bin_and(0xFF)
        |> BinaryUtil.append(package_buf.tmp)
      )

    package_buf
  end

  @spec fill_header(__MODULE__.t(), integer(), integer()) :: __MODULE__.t()
  def fill_header(package_buf, head, id) when head < 128 do
    package_buf = put_in(package_buf.tmp, BinaryUtil.append(head, package_buf.tmp))
    do_fill_header(package_buf, head, id)
  end

  def fill_header(package_buf, head, id) do
    package_buf =
      put_in(
        package_buf.tmp,
        head
        |> BinaryUtil.bin_and(0x7F00)
        |> BinaryUtil.bin_sr(8)
        |> BinaryUtil.bin_or(0x80)
        |> BinaryUtil.append(package_buf.tmp)
      )

    package_buf =
      put_in(
        package_buf.tmp,
        head
        |> BinaryUtil.bin_and(0xFF)
        |> BinaryUtil.append(package_buf.tmp)
      )

    do_fill_header(package_buf, head, id)
  end

  defp do_fill_header(package_buf, _head, id) do
    package_buf =
      put_in(
        package_buf.tmp,
        id
        |> BinaryUtil.bin_and(0xFF00)
        |> BinaryUtil.bin_sr(8)
        |> BinaryUtil.append(package_buf.tmp)
      )

    package_buf =
      put_in(
        package_buf.tmp,
        id
        |> BinaryUtil.bin_and(0xFF)
        |> BinaryUtil.append(package_buf.tmp)
      )

    package_buf
  end

  @spec pack_message(__MODULE__.t(), Message.t()) :: __MODULE__.t()
  def pack_message(package_buf, message) do
    general_package = ExRudp.general_package()

    case byte_size(message.buf) + 4 + byte_size(package_buf.tmp) >= general_package do
      true ->
        package_buf
        |> generate_new_package()
        |> do_pack_message(message)

      false ->
        do_pack_message(package_buf, message)
    end
  end

  defp do_pack_message(package_buf, message) do
    package_buf =
      fill_header(package_buf, byte_size(message.buf) + ExRudp.type_normal(), message.id)

    package_buf =
      put_in(
        package_buf.tmp,
        <<package_buf.tmp::binary, message.buf::binary>>
      )

    package_buf
  end

  defimpl Enumerable, for: ExRudp.Package.Buf do
    def count(%{__struct: ExRudp.Package.Buf, list: list} = _buf), do: {:ok, length(list)}

    def member?(%{__struct__: ExRudp.Package.Buf} = _buf, _elem) do
      {:error, ExRudp.Package.Buf}
    end

    def reduce(_buf, {:halt, acc}, _fun), do: {:halted, acc}

    def reduce(buf, {:suspend, acc}, fun) do
      {:suspended, acc, &reduce(buf, &1, fun)}
    end

    def reduce(
          %{__struct__: ExRudp.Package.Buf, list: []} = _buf,
          {:cont, acc},
          _fun
        ) do
      {:done, acc}
    end

    def reduce(
          %{__struct__: ExRudp.Package.Buf, list: [head | tail]} = buf,
          {:cont, acc},
          fun
        ) do
      buf = put_in(buf.list, tail)
      reduce(buf, fun.(head, acc), fun)
    end

    def slice(%{__struct__: ExRudp.Package.Buf, list: list} = _buf) do
      {:ok, length(list), &slicing_fun(list, &1, &2)}
    end

    defp slicing_fun(buf, start, length) do
      Enum.slice(buf, start, length)
    end
  end
end
