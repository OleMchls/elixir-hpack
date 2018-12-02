ExUnit.start()

defmodule RFCBinaries do
  def sigil_b(string, []) do
    string
    |> String.split("\n")
    |> Enum.map(fn part -> String.split(part, "|") |> List.first() end)
    |> Enum.map(fn part -> String.split(part, " ") end)
    |> List.flatten()
    |> Enum.filter(&(byte_size(&1) > 0))
    |> Enum.map(fn part -> String.to_integer(part, 16) end)
    |> Enum.map(fn i ->
      case i do
        x when x in 0..255 -> <<x::size(8)>>
        x when x in 256..65535 -> <<x::size(16)>>
      end
    end)
    |> Enum.reduce(fn b, acc -> acc <> b end)
  end
end
