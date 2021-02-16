defmodule Filex.Config.SSHDaemonOptions do
  @behaviour Filex.Config
  def configure(options, additional_options) do
    options
    |> Keyword.merge(additional_options |> Enum.map(&ssh_daemon_option/1))
  end

  def ssh_daemon_option({:system_dir, _} = option), do: path_option(option)
  def ssh_daemon_option({:user_dir, _} = option), do: path_option(option)

  def ssh_daemon_option({:pwdfun, value}) when is_function(value, 2), do: {:pwdfun, value}
  def ssh_daemon_option({:pwdfun, value}) when is_function(value, 4), do: {:pwdfun, value}

  def ssh_daemon_option({:pwdfun, _}),
    do: raise(Filex.InvalidConfigError, "Invalid :pwdfun option. Expecting a function /2 or /4")

  def ssh_daemon_option({key, value}), do: {key, value}

  defp path_option({name, value}) when is_binary(value),
    do: {name, value |> String.to_charlist()}

  defp path_option({name, value}) when is_list(value) do
    if List.ascii_printable?(value) do
      {name, value}
    else
      raise Filex.InvalidConfigError,
            "Invalid name option. Expecting a dir path as a string or printable charlist"
    end
  end

  defp path_option({name, _value}) do
    raise Filex.InvalidConfigError,
          "Invalid #{name} option. Expecting a dir path as a string or printable charlist"
  end
end
