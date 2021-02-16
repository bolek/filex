defmodule Filex.SftpdChannel do
  @behaviour :ssh_server_channel

  require Logger
  require Record

  Record.defrecord(:state, Record.extract(:state, from_lib: "ssh/src/ssh_sftpd.erl"))
  Record.defrecord(:ssh_xfer, Record.extract(:ssh_xfer, from_lib: "ssh/src/ssh_xfer.erl"))

  def subsystem_spec(options) do
    {'sftp', {Filex.SftpdChannel, options}}
  end

  @impl :ssh_server_channel
  def init(options) do
    :ssh_sftpd.init(options)
  end

  @impl :ssh_server_channel
  def handle_msg(msg, state) do
    # Logger.info(inspect(msg))
    # Logger.info(inspect(state))
    :ssh_sftpd.handle_msg(msg, state)
  end

  defp to_record(record) do
    Enum.map(record, fn {_k, v} -> v end) |> List.insert_at(0, :state) |> List.to_tuple()
  end

  def ensure_dir(file_handler, path), do: file_handler.ensure_dir(path)

  defp populate_file_state(state) do
    file_handler = Keyword.fetch!(state, :file_handler)

    file_state = state[:file_state]

    if file_state[:user] do
      file_state
    else
      event_handler = file_state[:event_handler]

      user_root_dir = file_state[:user_root_dir]

      xf = ssh_xfer(state[:xf])
      [user: username] = :ssh.connection_info(xf[:cm], [:user])

      root_path =
        if is_function(user_root_dir) do
          user_root_dir.(username)
        else
          "#{user_root_dir}/#{username}"
        end

      # make sure directory exists
      {:ok, _path} = ensure_dir(file_handler, root_path)

      file_state
      |> List.keystore(:event_handler, 0, {:event_handler, event_handler})
      |> List.keystore(:user, 0, {:user, username})
      |> List.keystore(:root_path, 0, {:root_path, root_path})
    end
  end

  @impl :ssh_server_channel
  def handle_ssh_msg(msg, state) do
    # IO.inspect("received msg")
    s = state(state)
    file_state = populate_file_state(s)
    new_state = List.keystore(s, :file_state, 0, {:file_state, file_state})
    # IO.inspect(new_state)
    :ssh_sftpd.handle_ssh_msg(msg, to_record(new_state))
  end

  @impl :ssh_server_channel
  def terminate(reason, state) do
    :ssh_sftpd.terminate(reason, state)
  end
end