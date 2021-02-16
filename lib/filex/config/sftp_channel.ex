defmodule Filex.Config.SFTPChannel do
  @behaviour Filex.Config
  def configure(ssh_options, sftpd_spec) do
    subsystem_spec =
      [cwd: '/']
      |> Keyword.merge(sftpd_spec)
      |> Filex.SftpdChannel.subsystem_spec()

    ssh_options
    |> Filex.Config.SSHDaemonOptions.configure(subsystems: [subsystem_spec])
  end
end
