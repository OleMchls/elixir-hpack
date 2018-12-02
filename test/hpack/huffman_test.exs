defmodule HuffmanTest do
  use ExUnit.Case, async: true

  doctest HPack.Huffman

  alias HPack.Huffman

  test "decode a simple character" do
    assert "%" == Huffman.decode(<<0x15::6>>)
  end

  test "decode a sentence" do
    hello_world = <<
      0x27::6,
      0x5::5,
      0x28::6,
      0x28::6,
      0x7::5,
      0x14::6,
      0x78::7,
      0x7::5,
      0x2C::6,
      0x28::6,
      0x24::6,
      0x3F8::10
    >>

    assert "hello world!" == Huffman.decode(hello_world)
  end

  test "decode with padding" do
    hello = <<
      0x27::6,
      0x5::5,
      0x28::6,
      0x28::6,
      0x7::5,
      0b1111::4
    >>

    assert "hello" == Huffman.decode(hello)
  end

  test "encode a simple character" do
    assert Huffman.encode("%") == <<0b01010111>>
  end

  test "encode two simple characters" do
    assert Huffman.encode("%%") == <<0b0101010101011111::16>>
  end

  test "encode a sentence" do
    assert Huffman.encode("hello world!") == <<
             0x27::6,
             0x5::5,
             0x28::6,
             0x28::6,
             0x7::5,
             0x14::6,
             0x78::7,
             0x7::5,
             0x2C::6,
             0x28::6,
             0x24::6,
             0x3F8::10,
             0b111111::6
           >>
  end
end
