defmodule Filex.NoShell do
  def shell(user, {ip, _port}) do
    spawn(fn ->
      remote_ip = ip |> Tuple.to_list() |> Enum.join(".")
      IO.puts("Hello, #{user} from #{remote_ip}")
      IO.puts("No shell available for you here")
    end)
  end
end
