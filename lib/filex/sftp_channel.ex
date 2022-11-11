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
    :ssh_sftpd.handle_msg(msg, state)
  end

  @impl :ssh_server_channel
  def handle_ssh_msg(msg, state) do
    s = state(state)
    file_state = populate_file_state(s)

    new_state = List.keystore(s, :file_state, 0, {:file_state, file_state})

    :ssh_sftpd.handle_ssh_msg(msg, to_record(new_state))
  end

  @impl :ssh_server_channel
  def terminate(reason, state) do
    :ssh_sftpd.terminate(reason, state)
  end

  defp to_record(record) do
    Enum.map(record, fn {_k, v} -> v end) |> List.insert_at(0, :state) |> List.to_tuple()
  end

  defp populate_file_state(state) do
    file_state = state[:file_state]

    # if user session initiated
    if Filex.Storage.FileState.user(file_state) do
      file_state
    else
      xf = ssh_xfer(state[:xf])
      [user: user] = :ssh.connection_info(xf[:cm], [:user])

      Filex.Storage.initialize_user_file_state(file_state, to_string(user))
    end
  end
end
