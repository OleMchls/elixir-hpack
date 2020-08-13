defmodule HPack do
  @moduledoc """
    Implementation of the [HPack](https://http2.github.io/http2-spec/compression.html) protocol, a compression format for efficiently representing HTTP header fields, to be used in HTTP/2.
  """

  use Bitwise
  alias HPack.Huffman
  alias HPack.Table

  @type name() :: String.t()
  @type value() :: String.t()
  @type header() :: {name(), value()}
  @type headers() :: [header()]
  @type header_block_fragment :: binary

  @doc """
  Encodes a list of headers into a `header block fragment` as specified in RFC 7541.

  Returns the `header block fragment`.

  ### Examples

      iex> {:ok, table, << 0b10000010 >>} = 1_000 |> HPack.Table.new() |> HPack.encode([{":method", "GET"}])
      {:ok, %HPack.Table{size: 1000, table: []}, <<130>>}
  """
  @spec encode(Table.t(), headers()) ::
          {:ok, Table.t(), header_block_fragment()} | {:error, :encode_error}
  def encode(table, headers), do: encode(table, headers, <<>>)

  defp encode(table, [], hbf), do: {:ok, table, hbf}

  defp encode(table, [{name, value} | headers], hbf) do
    {table, partial} =
      case Table.find(table, name, value) do
        {:fullindex, index} -> encode_indexed(table, index)
        {:keyindex, index} -> encode_literal_indexed(table, index, value)
        {:error, :not_found} -> encode_literal_not_indexed(table, name, value)
      end

    encode(table, headers, hbf <> partial)
  end

  defp encode(_headers, _hbf, _table), do: {:error, :encode_error}

  defp encode_indexed(table, index), do: {table, <<1::1, encode_int7(index)::bitstring>>}

  defp encode_literal_indexed(table, index, value) do
    with {:ok, {name, _}} <- Table.lookup(table, index),
         {:ok, table} <- Table.add(table, {name, value}) do
      {table, <<0::1, 1::1, encode_int6(index)::bitstring, encode_string(value)::binary>>}
    end
  end

  defp encode_literal_not_indexed(table, name, value) do
    with {:ok, table} <- Table.add(table, {name, value}),
         do:
           {table,
            <<0::1, 1::1, 0::6, encode_string(name)::binary, encode_string(value)::binary>>}
  end

  # defp encode_literal_never_indexed(key, value)

  defp encode_string(string) do
    with {:ok, huffman} <- Huffman.encode(string) do
      length = byte_size(huffman)
      <<1::1, encode_int7(length)::bitstring, huffman::binary>>
    end
  end

  defp encode_int6(i) when i < 0b111111, do: <<i::6>>
  defp encode_int6(i), do: <<0b111111::6, encode_big_int(i - 0b111111)::bitstring>>

  defp encode_int7(i) when i < 0b1111111, do: <<i::7>>
  defp encode_int7(i), do: <<0b1111111::7, encode_big_int(i - 0b1111111)::bitstring>>

  defp encode_big_int(i) when i < 0b10000000, do: <<0::1, i::7>>
  defp encode_big_int(i), do: <<1::1, i::7, encode_big_int(i >>> 7)::binary>>

  @doc """
  Decodes a `header block fragment` as specified in RFC 7541.

  Returns the decoded headers as a List.

  ### Examples

      iex> {:ok, table, [{":method", "GET"}]} = 1_000 |> HPack.Table.new() |> HPack.decode(<< 0x82 >>)
      {:ok, %HPack.Table{size: 1000, table: []}, [{":method", "GET"}]}
  """
  @spec decode(Table.t(), header_block_fragment, Table.size() | nil) ::
          {:ok, Table.t(), headers()} | {:error, :decode_error}
  def decode(table, hbf, max_size \\ nil)

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 0 | 1 |   Max size (5+)   |
  # +---+---------------------------+
  # Figure 12: Maximum Dynamic Table Size Change
  def decode(table, <<0::2, 1::1, rest::bitstring>>, max_size) do
    with {:ok, {size, rest}} <- parse_int5(rest),
         {:ok, table} <- Table.resize(table, size, max_size),
         do: decode(table, rest, max_size)
  end

  def decode(table, hbf, _max_size) do
    parse(table, hbf, [])
  end

  defp parse(table, <<>>, headers), do: {:ok, table, Enum.reverse(headers)}

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 1 |        Index (7+)         |
  # +---+---------------------------+
  #  Figure 5: Indexed Header Field
  defp parse(table, <<1::1, rest::bitstring>>, headers) do
    with {:ok, {index, rest}} <- parse_int7(rest),
         {:ok, {header, value}} <- Table.lookup(table, index),
         do: parse(table, rest, [{header, value} | headers])
  end

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 1 |           0           |
  # +---+---+-----------------------+
  # | H |     Name Length (7+)      |
  # +---+---------------------------+
  # |  Name String (Length octets)  |
  # +---+---------------------------+
  # | H |     Value Length (7+)     |
  # +---+---------------------------+
  # | Value String (Length octets)  |
  # +-------------------------------+
  # Figure 7: Literal Header Field with Incremental Indexing — New Name
  defp parse(table, <<0::1, 1::1, 0::6, rest::binary>>, headers) do
    with {:ok, {name, rest}} <- parse_string(rest),
         {:ok, {value, more_headers}} <- parse_string(rest) do
      with {:ok, table} <- Table.add(table, {name, value}),
           do: parse(table, more_headers, [{name, value} | headers])
    end
  end

  #  0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 1 |      Index (6+)       |
  # +---+---+-----------------------+
  # | H |     Value Length (7+)     |
  # +---+---------------------------+
  # | Value String (Length octets)  |
  # +-------------------------------+
  # Figure 6: Literal Header Field with Incremental Indexing — Indexed Name
  defp parse(table, <<0::1, 1::1, rest::bitstring>>, headers) do
    with {:ok, {index, rest}} <- parse_int6(rest),
         {:ok, {value, more_headers}} <- parse_string(rest),
         {:ok, {name, _}} <- Table.lookup(table, index),
         {:ok, table} <- Table.add(table, {name, value}) do
      parse(table, more_headers, [{name, value} | headers])
    end
  end

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 0 | 0 | 0 |       0       |
  # +---+---+-----------------------+
  # | H |     Name Length (7+)      |
  # +---+---------------------------+
  # |  Name String (Length octets)  |
  # +---+---------------------------+
  # | H |     Value Length (7+)     |
  # +---+---------------------------+
  # | Value String (Length octets)  |
  # +-------------------------------+
  # Figure 9: Literal Header Field without Indexing — New Name
  defp parse(table, <<0::4, 0::4, rest::binary>>, headers) do
    with {:ok, {name, rest}} <- parse_string(rest),
         {:ok, {value, more_headers}} <- parse_string(rest),
         do: parse(table, more_headers, [{name, value} | headers])
  end

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 0 | 0 | 0 |  Index (4+)   |
  # +---+---+-----------------------+
  # | H |     Value Length (7+)     |
  # +---+---------------------------+
  # | Value String (Length octets)  |
  # +-------------------------------+
  # Figure 8: Literal Header Field without Indexing — Indexed Name
  defp parse(table, <<0::4, rest::bitstring>>, headers) do
    with {:ok, {index, rest}} <- parse_int4(rest),
         {:ok, {value, more_headers}} <- parse_string(rest),
         {:ok, {name, _}} <- Table.lookup(table, index),
         do: parse(table, more_headers, [{name, value} | headers])
  end

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 0 | 0 | 1 |       0       |
  # +---+---+-----------------------+
  # | H |     Name Length (7+)      |
  # +---+---------------------------+
  # |  Name String (Length octets)  |
  # +---+---------------------------+
  # | H |     Value Length (7+)     |
  # +---+---------------------------+
  # | Value String (Length octets)  |
  # +-------------------------------+
  # Figure 11: Literal Header Field Never Indexed — New Name
  defp parse(table, <<0::3, 1::1, 0::4, rest::binary>>, headers) do
    with {:ok, {name, rest}} <- parse_string(rest),
         {:ok, {value, more_headers}} <- parse_string(rest),
         do: parse(table, more_headers, [{name, value} | headers])
  end

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 0 | 0 | 1 |  Index (4+)   |
  # +---+---+-----------------------+
  # | H |     Value Length (7+)     |
  # +---+---------------------------+
  # | Value String (Length octets)  |
  # +-------------------------------+
  # Figure 10: Literal Header Field Never Indexed — Indexed Name
  defp parse(table, <<0::3, 1::1, rest::bitstring>>, headers) do
    with {:ok, {index, rest}} <- parse_int4(rest),
         {:ok, {value, more_headers}} <- parse_string(rest),
         {:ok, {name, _}} <- Table.lookup(table, index),
         do: parse(table, more_headers, [{name, value} | headers])
  end

  defp parse(_table, _binary, _headers), do: {:error, :decode_error}

  defp parse_string(<<0::1, rest::bitstring>>) do
    with {:ok, {length, rest}} <- parse_int7(rest),
         <<value::binary-size(length), rest::binary>> <- rest,
         do: {:ok, {value, rest}}
  end

  defp parse_string(<<1::1, rest::bitstring>>) do
    with {:ok, {length, rest}} <- parse_int7(rest),
         <<value::binary-size(length), rest::binary>> <- rest,
         {:ok, encoded} <- Huffman.decode(value),
         do: {:ok, {encoded, rest}}
  end

  defp parse_string(_binary), do: {:error, :decode_error}

  defp parse_int4(<<0b1111::4, rest::binary>>), do: parse_big_int(rest, 15, 0)
  defp parse_int4(<<int::4, rest::binary>>), do: {:ok, {int, rest}}
  defp parse_int4(_binary), do: {:error, :decode_error}

  defp parse_int5(<<0b11111::5, rest::binary>>), do: parse_big_int(rest, 31, 0)
  defp parse_int5(<<int::5, rest::binary>>), do: {:ok, {int, rest}}
  defp parse_int5(_binary), do: {:error, :decode_error}

  defp parse_int6(<<0b111111::6, rest::binary>>), do: parse_big_int(rest, 63, 0)
  defp parse_int6(<<int::6, rest::binary>>), do: {:ok, {int, rest}}
  defp parse_int6(_binary), do: {:error, :decode_error}

  defp parse_int7(<<0b1111111::7, rest::binary>>), do: parse_big_int(rest, 127, 0)
  defp parse_int7(<<int::7, rest::binary>>), do: {:ok, {int, rest}}
  defp parse_int7(_binary), do: {:error, :decode_error}

  defp parse_big_int(<<0::1, value::7, rest::binary>>, int, m),
    do: {:ok, {int + (value <<< m), rest}}

  defp parse_big_int(<<1::1, value::7, rest::binary>>, int, m),
    do: parse_big_int(rest, int + (value <<< m), m + 7)

  defp parse_big_int(_binary, _int, _m), do: {:error, :decode_error}
end
