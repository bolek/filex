defmodule Filex.Server.S3IntegrationTest do
  use ExUnit.Case, async: false

  setup_all do
    port = 8901

    {:ok, _} =
      Filex.Server.start_link(
        [
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
          }
        ],
        name: :s3_sftp
      )

    {:ok, port: port}
  end

  test "using s3 storage", %{port: port} do
    Filex.Support.GenericIntegrationTest.test_server(port)
  end
end
