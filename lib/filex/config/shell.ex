defmodule Filex.Config.Shell do
  @behaviour Filex.Config
  require Logger

  def configure(ssh_options, fun) when is_function(fun, 2) do
    ssh_options
    |> Filex.Config.SSHDaemonOptions.configure(shell: fun)
  end

  def configure(ssh_options, []) do
    Logger.warn("Provided empty shell config. Skipping.")

    ssh_options
  end

  def configure(_ssh_options, _) do
    raise Filex.InvalidConfigError, "Invalid shell config. Expecting a fn/2."
  end
end
