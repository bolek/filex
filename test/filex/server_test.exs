defmodule Filex.ServerTest do
  use ExUnit.Case
  doctest Filex

  @tag capture_log: true
  test "using local storage" do
    port = 8900

    {:ok, _pid} =
      Filex.Server.start_link(
        port: port,
        authentication: [{'lynx', 'test'}],
        storage: Filex.Storage.Local,
        system_dir: Path.expand("./tmp")
      )

    test_server(8900)
  end

  def test_server(port) do
    :ssh.start()

    # connect
    assert {:ok, channel, ref} =
             :ssh_sftp.start_channel('localhost', port,
               user: 'lynx',
               password: 'test',
               user_interaction: false,
               silently_accept_hosts: true
             )

    # list root directory
    assert :ssh_sftp.list_dir(channel, ".") == {:ok, []}

    # write to file
    content = "Abracadabra Poof!"

    assert :ssh_sftp.write_file(
             channel,
             "uploaded.txt",
             content
           ) == :ok

    assert :ssh_sftp.list_dir(channel, ".") == {:ok, ['uploaded.txt']}

    # read file
    assert :ssh_sftp.read_file(channel, 'uploaded.txt') == {:ok, content}

    # delete file
    assert :ssh_sftp.delete(channel, "uploaded.txt") == :ok
    assert :ssh_sftp.list_dir(channel, ".") == {:ok, []}
  end
end
