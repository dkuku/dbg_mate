# DbgMate

This package includes custom dbg functions

### DbgMate.Backport.dbg
Backport module currently includes dbg implementation for:

  - pipes
  - binary operators: and, or, ||, &&
  - code blocks wrapped in brackets
  - conditions: case, cond, if, unless, with


### DbgMate.Inspect.dbg
Wraps your code in IO.inspect calls used for showing the intermediate results.
The difference between the upstream dbg function is that it displays as the code
is executed and is not waiting until a block of code finishes.
It also works with whole modules and functions

```elixir
defmodule X do
    def y do: :z
end
|> dbg
```

### DbgMate.Inspect.dbg_tc
Wraps your code in IO.inspect calls used for showing the intermediate results
and additionally shows the time it took to execute every line.

To use it just set the config value in config or run this before your dbg call

```elixir
config :elixir, :dbg_callback, {DbgMate,Backport, :dbg, []})
```

or in livebook

```elixir
Mix.install(
    [
    {:dbg_mate, "~> 0.1.0"}
    ],
    config: [elixir: [dbg_callback: {DbgMate.Inspect, :dbg_tc, []}]]
)
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `dbg_mate` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dbg_mate, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/dbg_mate>.

