# Filex

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `filex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:filex, "~> 0.1.0"}
  ]
end
```

## Running Tests

### Requirements

- [Docker](https://docs.docker.com/engine/install/)

1. Run [LocalStack](https://github.com/localstack/localstack) container (for AWS S3 tests)

```
./scripts/localstack/init.sh
```

2. Setup bucket

```
./scripts/localstack/setup.sh
```

3. Run tests

```elixir
mix test
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/filex](https://hexdocs.pm/filex).
