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

  @spec bin_and(integer(), integer()) :: integer()
  def bin_and(left, right), do: left &&& right

  @spec bin_or(integer(), integer()) :: integer()
  def bin_or(left, right), do: bor(left, right)

  @spec bin_sl(integer(), integer()) :: integer()
  def bin_sl(left, right), do: left <<< right

  @spec bin_sr(integer(), integer()) :: integer()
  def bin_sr(left, right), do: left >>> right
end
