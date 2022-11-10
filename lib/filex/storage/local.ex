defmodule Filex.Storage.Local do
  require Logger

  def spec(ssh_options, config) do
    options =
      config
      |> Keyword.merge(
        user_root_dir:
          Keyword.get_lazy(config, :user_root_dir, fn ->
            default_user_root_dir(ssh_options, config)
          end)
      )

    {Filex.Storage.Local.FileHandler, options}
  end

  def default_user_root_dir(ssh_options, _config) do
    create_default_user_dir(ssh_options)
    |> Filex.Utils.to_charlist!()
  end

  defp create_default_user_dir(ssh_options) do
    home_dir =
      Keyword.get(ssh_options, :system_dir, Filex.Utils.create_tmp_dir())
      |> Path.join("home")

    if !File.exists?(home_dir), do: :ok = File.mkdir_p!(home_dir)

    home_dir
  end

  defmodule FileHandler do
    defp user_path(path, state) do
      Path.join(state[:root_path], path)
    end

    defp user(state) do
      Keyword.get(state, :user, :anonymous) |> to_string
    end

    defp on_event({event_name, meta}, state) do
      Logger.metadata(user: user(state))
      Logger.debug("on_event: #{inspect(event_name)}, #{inspect(meta)}, #{inspect(state)}")

      case state[:event_handler] do
        nil -> nil
        {module, fun} -> apply(module, fun, [{event_name, state[:user], meta}])
        handler -> handler.({event_name, state[:user], meta})
      end
    end

    defp after_event(param, state, result) do
      on_event(param, state)
      result
    end

    defp get_file_info(io_device) do
      case :file.pid2name(io_device) do
        {:ok, filename} -> {io_device, filename}
        _ -> {io_device}
      end
    end

    def ensure_dir(path, state) do
      abs_path = user_path(path, state)

      if File.exists?(abs_path) do
        :ok
      else
        File.mkdir_p(abs_path)
      end
    end

    def close(io_device, state) do
      after_event({:close, get_file_info(io_device)}, state, {:file.close(io_device), state})
    end

    def delete(path, state) do
      after_event({:delete, path}, state, {:file.delete(user_path(path, state)), state})
    end

    def del_dir(path, state) do
      after_event({:del_dir, path}, state, {:file.del_dir_r(user_path(path, state)), state})
    end

    def get_cwd(state) do
      {:file.get_cwd(), state}
    end

    def is_dir(abs_path, state) do
      {:filelib.is_dir(user_path(abs_path, state)), state}
    end

    def list_dir(abs_path, state) do
      {:file.list_dir(user_path(abs_path, state)), state}
    end

    def make_dir(dir, state) do
      after_event({:make_dir, dir}, state, {:file.make_dir(user_path(dir, state)), state})
    end

    def make_symlink(path2, path, state) do
      after_event(
        {:make_symlink, {path2, path}},
        state,
        {:file.make_symlink(user_path(path2, state), user_path(path, state)), state}
      )
    end

    def open(path, flags, state) do
      {case :file.open(user_path(path, state), flags) do
         {:ok, pid} ->
           on_event({:open, {get_file_info(pid), path, flags}}, state)
           {:ok, pid}

         other ->
           other
       end, state}
    end

    def position(io_device, offs, state) do
      {:file.position(io_device, offs), state}
    end

    def read(io_device, len, state) do
      after_event({:read, get_file_info(io_device)}, state, {:file.read(io_device, len), state})
    end

    def read_link(path, state) do
      Logger.info("read_link/2")

      {:file.read_link(user_path(path, state)), state}
    end

    def read_link_info(path, state) do
      {:file.read_link_info(user_path(path, state)), state}
    end

    def read_file_info(path, state) do
      {:file.read_file_info(user_path(path, state)), state}
    end

    def rename(from_path, to_path, state) do
      abs_from_path = user_path(from_path, state)
      abs_to_path = user_path(to_path, state)

      outcome = :file.rename(abs_from_path, abs_to_path)

      after_event(
        {:rename, {from_path, to_path}},
        state,
        {outcome, state}
      )
    end

    def write(io_device, data, state) do
      after_event(
        {:write, get_file_info(io_device)},
        state,
        {:file.write(io_device, data), state}
      )
    end

    def write_file_info(path, info, state) do
      after_event(
        {:write_file_info, {path, info}},
        state,
        {:file.write_file_info(user_path(path, state), info), state}
      )
    end
  end
end
