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

## Quick Start

```elixir
Logger.configure_backend(
  :console,
  format: "[$level] $metadata $message\n",
  metadata: [:user]
)

port = 8901

{:ok, _pid} =
  Filex.Server.start_link(
    port: port,
    authentication: [{'lynx', 'test'}],
    storage: {
      Filex.Storage.S3,
      scheme: "http://",
      host: "localhost",
      port: 4566,
      region: "us-east-1",
      bucket: "filex-sftp",
      access_key_id: "",
      secret_access_key: ""
      #  access_key_id: [{:awscli, "default", 30}],
      #  secret_access_key: [{:awscli, "default", 30}]
    }
  )

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
