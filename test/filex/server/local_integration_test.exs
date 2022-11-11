defmodule Filex.Server.LocalIntegrationTest do
  use ExUnit.Case, async: false

  setup_all do
    port = 8900

    {:ok, _pid} =
      Filex.Server.start_link(
        [
          port: port,
          authentication: [{'lynx', 'test'}],
          storage: {Filex.Storage.Local, users_root_dir: Path.expand("./tmp/home")},
          system_dir: Path.expand("./tmp")
        ],
        name: :local_sftp
      )

    {:ok, port: port}
  end

  @tag capture_log: true
  test "using local storage", %{port: port} do
    Filex.Support.GenericIntegrationTest.test_server(port)
  end
end
