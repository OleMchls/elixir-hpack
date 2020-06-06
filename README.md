# HPack (RFC 7541) [![Build Status](https://travis-ci.org/nesQuick/elixir-hpack.svg?branch=master)](https://travis-ci.org/nesQuick/elixir-hpack)

Implementation of the [HPack](https://http2.github.io/http2-spec/compression.html) protocol, a compression format for efficiently representing HTTP header fields, to be used in HTTP/2.

## Installation

1. Add hpack to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:hpack, "~> 3.0.0"}]
  end
  ```

## Usage
The HPack library has a simple interface. You will need two functions:

### Decoding
```elixir
ctx = HPack.Table.new(1_000)
{:ok, table, headers} = HPack.decode(ctx, (<< 0x82 >>)
# => {:ok, ..., [{":method", "GET"}]}
```

### Encoding
```elixir
ctx = HPack.Table.new(1_000)
{:ok, table, hbf} = HPack.encode(ctx, [{":method", "GET"}])
# => {:ok, ..., << 0b10000010 >>}
```

## Acknowledgements
The [cowboy hpack implementation](https://github.com/ninenines/cowlib/blob/d0cd6dcb338425a24f85f37ab1ba6d9aeaca89bb/src/cow_hpack.erl#L563) by Loïc Hoguin (@essen) was a great help while writing this library.

## feature wishes / ideas / contribute
Nice to have:
- transcoding for intermediaries (`never indexed`)
- handle small tables in a performant way (keep track of headers)

*please write test <3*

## License

The MIT License (MIT)

Copyright (c) 2016 Ole Michaelis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
