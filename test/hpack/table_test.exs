defmodule HPack.TableTest do
  use ExUnit.Case, async: true

  alias HPack.Table
  doctest Table

  @max_size 1_000

  setup do
    {:ok, table: Table.new(@max_size)}
  end

  test "resize table to smaller than max size", %{table: table} do
    assert {:ok, _table} = Table.resize(table, @max_size / 2, @max_size)
  end

  test "resize table to equal to max size", %{table: table} do
    assert {:ok, _table} = Table.resize(table, @max_size, @max_size)
  end

  test "resize table to larger than max size fails", %{table: table} do
    assert {:error, :decode_error} = Table.resize(table, @max_size + 1, @max_size)
  end

  test "lookp up from static table", %{table: table} do
    assert {:ok, {":method", "GET"}} = Table.lookup(table, 2)
  end

  test "adding to dynamic table", %{table: table} do
    header = {"some-header", "some-value"}
    assert {:ok, table} = Table.add(table, header)
    assert {:ok, header} == Table.lookup(table, 62)
  end

  test "adds to dynamic table at the beginning", %{table: table} do
    second_header = {"some-header-2", "some-value-2"}
    assert {:ok, table} = Table.add(table, {"some-header", "some-value"})
    assert {:ok, table} = Table.add(table, second_header)
    assert {:ok, second_header} == Table.lookup(table, 62)
  end

  test "evict entries on table size change", %{table: table} do
    header = {"some-header", "some-value"}
    assert {:ok, table} = Table.add(table, header)
    # evict all entries in dynamic table
    assert {:ok, table} = Table.resize(table, 0)
    assert {:error, :not_found} == Table.lookup(table, 62)
  end

  test "evict oldest entries when size > table size", %{table: table} do
    assert {:ok, table} = Table.resize(table, 60)

    third_header = {"some-header-3", "some-value-3"}
    assert {:ok, table} = Table.add(table, {"some-header", "some-value"})
    assert {:ok, table} = Table.add(table, {"some-header-2", "some-value-2"})
    assert {:ok, table} = Table.add(table, third_header)

    assert {:ok, third_header} == Table.lookup(table, 62)
    assert {:error, :not_found} == Table.lookup(table, 63)
  end

  test "find a key with corresponding value from static table", %{table: table} do
    assert Table.find(table, ":method", "GET") == {:fullindex, 2}
  end

  test "find a key without corresponding value from static table", %{table: table} do
    assert Table.find(table, "etag", "1e2345678") == {:keyindex, 34}
  end

  test "return :none when key not found in table", %{table: table} do
    assert Table.find(table, "x-something", "some-value") == {:error, :not_found}
  end

  test "find a key with corresponding value from dynamic table", %{table: table} do
    assert {:ok, table} = Table.add(table, {"x-something", "some-value"})
    assert Table.find(table, "x-something", "some-value") == {:fullindex, 62}
  end
end
