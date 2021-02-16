defmodule Filex.Config.Authentication do
  @behaviour Filex.Config
  require Logger
  def configure(ssh_options, value)

  def configure(ssh_options, auth_fun) when is_function(auth_fun, 2) do
    configure_pwdfun(ssh_options, auth_fun)
  end

  def configure(ssh_options, auth_fun) when is_function(auth_fun, 4) do
    configure_pwdfun(ssh_options, auth_fun)
  end

  def configure(ssh_options, user_passwords) when is_list(user_passwords) do
    ssh_options
    |> Filex.Config.SSHDaemonOptions.configure(user_passwords: cast!(user_passwords))
  end

  def configure(ssh_options, _) do
    Logger.warn(
      "No such setting option for authentication. Skipping config. Check documentation."
    )

    ssh_options
  end

  defp cast!(user_passwords) do
    user_passwords
    |> Enum.map(fn
      {user, pass} ->
        {
          to_charlist(user),
          to_charlist(pass)
        }

      _ ->
        raise Filex.InvalidConfigError,
              "Invalid Authentication config. Expecting {user, pass} tuples in list."
    end)
  end

  defp configure_pwdfun(ssh_options, function) do
    ssh_options
    |> Filex.Config.SSHDaemonOptions.configure(pwdfun: function)
  end
end
