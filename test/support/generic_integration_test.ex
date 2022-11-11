defmodule Filex.Support.GenericIntegrationTest do
  use ExUnit.Case
  require Logger

  def test_server(port) do
    :ssh.start()

    # connect
    assert {:ok, channel, _ref} =
             :ssh_sftp.start_channel('localhost', port,
               user: 'lynx',
               password: 'test',
               user_interaction: false,
               silently_accept_hosts: true
             )

    :ssh_sftp.del_dir(channel, "test")
    :ssh_sftp.delete(channel, "uploaded.txt")
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

    assert :ssh_sftp.make_dir(channel, "test") == :ok
    assert :ssh_sftp.list_dir(channel, ".") == {:ok, ['test']}

    assert :ssh_sftp.write_file(
             channel,
             "test/uploaded.txt",
             content
           ) == :ok

    assert :ssh_sftp.list_dir(channel, "test") == {:ok, ['uploaded.txt']}

    assert :ssh_sftp.rename(channel, 'test/uploaded.txt', 'test/uploaded2.txt') == :ok
    assert :ssh_sftp.list_dir(channel, "test") == {:ok, ['uploaded2.txt']}

    assert :ssh_sftp.del_dir(channel, "test") == :ok
    assert :ssh_sftp.list_dir(channel, ".") == {:ok, []}

    Filex.Support.GenericIntegrationTest.disconnect(channel)
  end

  def connect!(port) do
    :ssh.start()

    # connect
    {:ok, channel, _ref} =
      :ssh_sftp.start_channel('localhost', port,
        user: 'lynx',
        password: 'test',
        user_interaction: false,
        silently_accept_hosts: true
      )

    channel
  end

  def disconnect(client) do
    :ssh_sftp.stop_channel(client)
  end
end
