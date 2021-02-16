defmodule Filex.Config.SFTPChannelTest do
  use ExUnit.Case, async: true

  alias Filex.Config.SFTPChannel

  describe "configure/2" do
    test "empty" do
      assert SFTPChannel.configure([], []) == [
               {:subsystems, [{'sftp', {Filex.SftpdChannel, [cwd: '/']}}]}
             ]
    end

    test "with file_handler" do
      assert SFTPChannel.configure([], file_handler: :ssh_sftpd_file) ==
               [
                 {:subsystems,
                  [{'sftp', {Filex.SftpdChannel, [cwd: '/', file_handler: :ssh_sftpd_file]}}]}
               ]
    end
  end
end
