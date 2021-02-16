defmodule Filex.Server do
  use GenServer
  require Logger

  @moduledoc """
    Configuration

    * `:port` - sftp port (default: 22)
    * `:system_dir` - system directory where configuration and keys are stored.
      If ssh_host_rsa_key doesn't exist, a new one will be created on init.
      Defaults to a random path in the OS temporary directory.
    * `:shell` - shell implementation (default: Elixir.Filex.DummyShell)
    * `:authentication` - function or list of user/passwords used for
      authentication. Required option.
    * `:storage` - file storage adapter
      Defaults to `Filex.Storage.Local`
  """

  def start_link(init_args \\ [], opts \\ []) do
    opts_with_defaults =
      [name: __MODULE__]
      |> Keyword.merge(opts)

    GenServer.start_link(__MODULE__, init_args, opts_with_defaults)
  end

  def init(opts \\ []) do
    port = Keyword.get(opts, :port, 22)
    system_dir = Keyword.get(opts, :system_dir, Filex.Utils.create_tmp_dir())
    shell = Keyword.get(opts, :shell, &Filex.NoShell.shell/2)
    storage = Keyword.get(opts, :storage, Filex.Storage.Local)
    authentication = Keyword.get(opts, :authentication)

    # Make system_dir if doesn't exist
    if !File.exists?(system_dir), do: File.mkdir_p!(system_dir)
    # Create host key if doesn't exist
    key_path = Path.join(system_dir, "ssh_host_rsa_key")

    if !File.exists?(key_path), do: Filex.Utils.create_host_key(key_path)

    ssh_daemon_opts =
      [
        {Filex.Config.SSHDaemonOptions, system_dir: system_dir},
        {Filex.Config.Shell, shell},
        {Filex.Config.Authentication, authentication},
        {Filex.Config.Storage, storage}
      ]
      |> Filex.Config.new()

    Logger.info("starting ssh")

    :ssh.start()

    case :ssh.daemon(port, ssh_daemon_opts) do
      {:ok, pid} ->
        Logger.info("sftp daemon started")
        {:ok, %{spec: opts, daemons: [%{pid: pid}]}}

      any ->
        any
    end
  end
end
