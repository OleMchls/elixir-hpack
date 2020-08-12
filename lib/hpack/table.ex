defmodule HPack.Table do
  @moduledoc """
    Functions to maintain the (de)compression context.
    Contains the static tables as well as all menagement of the dynamic table.
  """

  @type t :: pid

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

  @spec start_link(integer) :: {:ok, t}
  def start_link(max_table_size) do
    Agent.start_link(fn -> %{size: max_table_size, table: []} end)
  end

  @spec lookup(integer, t) :: {:ok, tuple} | {:error, :not_found}
  def lookup(idx, table) do
    case Enum.at(full_table(table), idx - 1) do
      tuple when not is_nil(tuple) ->
        {:ok, tuple}

      _ ->
        {:error, :not_found}
    end
  end

  @spec find(String.t(), String.t(), t) :: {:error, :not_found} | {:keyindex, integer} | {:fullindex, integer}
  def find(key, value, table) do
    match_on_key_and_value =
      Enum.find_index(full_table(table), fn {ck, cv} -> ck == key && cv == value end)

    match_on_key = Enum.find_index(full_table(table), fn {ck, _} -> ck == key end)

    cond do
      match_on_key_and_value != nil -> {:fullindex, match_on_key_and_value + 1}
      match_on_key != nil -> {:keyindex, match_on_key + 1}
      true -> {:error, :not_found}
    end
  end

  @spec add({String.t(), String.t()}, t) :: :ok
  def add({key, value}, table) do
    Agent.update(table, fn state ->
      %{state | table: [{key, value} | state.table]}
    end)

    check_size(table)
  end

  @spec resize(integer, t, integer | nil) :: :ok | {:error, :decode_error}
  def resize(size, table, max_size \\ nil)

  def resize(size, table, max_size)
  when not is_integer(max_size) or size <= max_size do
    Agent.update(table, fn state ->
      %{state | size: size}
    end)

    check_size(table)
  end

  def resize(_size, _table, _max_size), do: {:error, :decode_error}

  @spec size(t) :: integer
  def size(table) do
    Agent.get(table, &calculate_size(&1.table))
  end

  # check table size and evict entries when neccessary
  defp check_size(table_pid) do
    Agent.update(table_pid, fn %{size: size, table: table} ->
      new_table = evict(calculate_size(table) > size, table, size)
      %{size: size, table: new_table}
    end)
  end

  defp calculate_size([]), do: 0

  defp calculate_size(table) do
    table
    |> Enum.map(fn {key, value} -> byte_size(key) + byte_size(value) + 32 end)
    |> Enum.reduce(fn x, acc -> x + acc end)
  end

  defp evict(true, table, size) do
    new_table = List.delete_at(table, length(table) - 1)
    evict(calculate_size(new_table) > size, new_table, size)
  end

  defp evict(false, table, _), do: table

  defp full_table(table), do: @static ++ Agent.get(table, & &1.table)
end
