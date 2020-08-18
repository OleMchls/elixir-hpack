defmodule HPack.Table do
  @moduledoc """
    Functions to maintain the (de)compression context.
    Contains the static tables as well as all menagement of the dynamic table.
  """

  @static [
    {":authority", nil},
    {":method", "GET"},
    {":method", "POST"},
    {":path", "/"},
    {":path", "/index.html"},
    {":scheme", "http"},
    {":scheme", "https"},
    {":status", "200"},
    {":status", "204"},
    {":status", "206"},
    {":status", "304"},
    {":status", "400"},
    {":status", "404"},
    {":status", "500"},
    {"accept-charset", nil},
    {"accept-encoding	gzip, deflate", nil},
    {"accept-language", nil},
    {"accept-ranges", nil},
    {"accept", nil},
    {"access-control-allow-origin", nil},
    {"age", nil},
    {"allow", nil},
    {"authorization", nil},
    {"cache-control", nil},
    {"content-disposition", nil},
    {"content-encoding", nil},
    {"content-language", nil},
    {"content-length", nil},
    {"content-location", nil},
    {"content-range", nil},
    {"content-type", nil},
    {"cookie", nil},
    {"date", nil},
    {"etag", nil},
    {"expect", nil},
    {"expires", nil},
    {"from", nil},
    {"host", nil},
    {"if-match", nil},
    {"if-modified-since", nil},
    {"if-none-match", nil},
    {"if-range", nil},
    {"if-unmodified-since", nil},
    {"last-modified", nil},
    {"link", nil},
    {"location", nil},
    {"max-forwards", nil},
    {"proxy-authenticate", nil},
    {"proxy-authorization", nil},
    {"range", nil},
    {"referer", nil},
    {"refresh", nil},
    {"retry-after", nil},
    {"server", nil},
    {"set-cookie", nil},
    {"strict-transport-security", nil},
    {"transfer-encoding", nil},
    {"user-agent", nil},
    {"vary", nil},
    {"via", nil},
    {"www-authenticate", nil}
  ]

  @type size() :: non_neg_integer()
  @type table() :: list()
  @type index() :: non_neg_integer()
  @opaque t :: %__MODULE__{
            size: size(),
            table: table()
          }

  defstruct size: nil, table: []

  @spec new(size()) :: t()
  def new(max_table_size) do
    %__MODULE__{size: max_table_size}
  end

  @spec lookup(index(), t()) :: {:ok, HPack.header()} | {:error, :not_found}
  def lookup(index, %{table: table}) do
    table
    |> full_table()
    |> Enum.at(index - 1)
    |> case do
      header when not is_nil(header) ->
        {:ok, header}

      _ ->
        {:error, :not_found}
    end
  end

  @spec find(HPack.name(), HPack.value(), t()) ::
          {:error, :not_found} | {:keyindex, integer} | {:fullindex, integer}
  def find(name, value, %{table: table}) do
    match_on_key_and_value =
      table
      |> full_table()
      |> Enum.find_index(fn {ck, cv} -> ck == name && cv == value end)

    match_on_key =
      table
      |> full_table()
      |> Enum.find_index(fn {ck, _} -> ck == name end)

    cond do
      match_on_key_and_value != nil -> {:fullindex, match_on_key_and_value + 1}
      match_on_key != nil -> {:keyindex, match_on_key + 1}
      true -> {:error, :not_found}
    end
  end

  @spec add(HPack.header(), t()) :: {:ok, t()}
  def add({key, value}, %{table: table} = context) do
    {:ok, check_size(%{context | table: [{key, value} | table]})}
  end

  @spec resize(size(), t(), size() | nil) :: {:ok, t()} | {:error, :decode_error}
  def resize(size, context, max_size \\ nil)

  def resize(size, context, max_size)
      when not is_integer(max_size) or size <= max_size do
    {:ok, check_size(%{context | size: size})}
  end

  def resize(_size, _context, _max_size), do: {:error, :decode_error}

  @spec size(t()) :: size()
  def size(%{table: table}), do: calculate_size(table)

  # check table size and evict entries when neccessary
  defp check_size(%{size: size, table: table} = context) do
    %{context | size: size, table: evict(calculate_size(table) > size, table, size)}
  end

  defp calculate_size(table) do
    Enum.reduce(table, 0, fn {key, value}, acc -> acc + byte_size(key) + byte_size(value) + 32 end)
  end

  defp evict(true, table, size) do
    new_table = List.delete_at(table, length(table) - 1)
    evict(calculate_size(new_table) > size, new_table, size)
  end

  defp evict(false, table, _), do: table

  defp full_table(table), do: @static ++ table
end
