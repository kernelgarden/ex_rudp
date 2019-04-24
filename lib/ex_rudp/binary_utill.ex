defmodule ExRudp.BinaryUtil do
  use Bitwise

  @spec append(integer(), binary()) :: binary()
  def append(value, bin) when is_integer(value) do
    <<bin::binary, :binary.encode_unsigned(value)::binary>>
  end

  @spec append(list(integer()), binary()) :: binary()
  def append(values, bin) when is_list(values) do
    additional_bin =
      values
      |> Enum.reduce(<<>>, fn value, acc ->
        <<acc::binary, :binary.encode_unsigned(value)::binary>>
      end)

    <<bin::binary, additional_bin::binary>>
  end

  def bin_and(left, right), do: left &&& right

  def bin_or(left, right), do: bor(left, right)

  def bin_sl(left, right), do: left <<< right

  def bin_sr(left, right), do: left >>> right
end
