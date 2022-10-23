defmodule Filex.Storage.S3 do
  require Logger

  def spec(_ssh_options, options) do
    {event_handler, options} = Keyword.pop!(options, :event_handler)

    {Filex.Storage.S3.FileHandler,
     event_handler: event_handler,
     root_path: "/",
     aws_config: Filex.Storage.S3.Config.new(options)}
  end

  defmodule FileHandler do
    defp aws_config(state) do
      Keyword.fetch!(state, :aws_config)
    end

    defp ex_aws_config(state) do
      state
      |> aws_config()
      |> Filex.Storage.S3.Config.ex_aws_config()
    end

    defp bucket(state) do
      state
      |> aws_config()
      |> Filex.Storage.S3.Config.bucket()
    end

    # defp user_path(".", state) do
    #   user_path("", state)
    # end

    defp user_path(path, state) do
      Path.join(state[:root_path], path)
      |> String.trim_leading("/")
      |> String.trim_trailing(".")
    end

    defp on_event({event_name, meta}, state) do
      Logger.metadata(user: user(state))
      Logger.info("on_event: #{inspect(event_name)}")

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

    # defp get_file_info(rel_path, state) do
    #   bucket(state)
    #   |> ExAws.S3.get_object(user_path(rel_path, state))
    #   |> ExAws.request(ex_aws_config(state))

    #   # case :file.pid2name(io_device) do
    #   #   {:ok, filename} -> {io_device, filename}
    #   #   _ -> {io_device}
    #   # end
    # end

    def ensure_dir(path) do
      {:ok, path}
    end

    def close(%ExAws.S3.Upload{} = upload_op, state) do
      parts =
        Keyword.get(state, :aws_upload_progress)
        |> Map.fetch!(:parts)

      case Enum.find(parts, fn
             {:error, _} -> true
             _ -> false
           end) do
        nil ->
          ExAws.S3.Upload.complete(parts, upload_op, ex_aws_config(state))
          Keyword.delete(state, :aws_upload_progress)

        error ->
          error
      end

      get_file_info = %{}
      after_event({:close, get_file_info}, state, {:ok, state})
    end

    def close(io_device, state) do
      Logger.info("close #{inspect(io_device)}")
      get_file_info = %{}
      after_event({:close, get_file_info}, state, {:ok, state})
    rescue
      e ->
        Logger.error(e)
    end

    def delete(rel_path, state) do
      result =
        bucket(state)
        |> ExAws.S3.delete_object(user_path(rel_path, state))
        |> ExAws.request(ex_aws_config(state))
        |> case do
          {:ok, _} -> :ok
          error -> error
        end

      after_event({:delete, rel_path}, state, {result, state})
    end

    def del_dir(path, state) do
      after_event({:del_dir, path}, state, {:file.del_dir(user_path(path, state)), state})
    end

    def get_cwd(state) do
      # { Keyword.get(state, :cwd, user_path(".", state))}")
      {:file.get_cwd(), state}
    end

    def is_dir(rel_path, state)
    def is_dir('/', state), do: {true, state}

    def is_dir(rel_path, state) do
      Logger.info("is dir: #{rel_path}")

      is_dir =
        bucket(state)
        |> ExAws.S3.get_object(user_path(rel_path, state))
        |> ExAws.request(ex_aws_config(state) |> Map.to_list())
        |> case do
          {:ok, %{headers: headers, status_code: 200}} ->
            Enum.any?(headers, fn
              {"Content-Type", "application/x-directory; charset=UTF-8"} -> true
              _ -> false
            end)

          _ ->
            false
        end

      {is_dir, state}
    rescue
      e ->
        Logger.error(e)
    end

    def list_dir(rel_path, state) do
      Logger.info("list dir: #{inspect(rel_path)}")

      abs_path = user_path(rel_path, state)

      objects =
        bucket(state)
        |> ExAws.S3.list_objects(
          delimiter: "/",
          prefix: abs_path
        )
        |> ExAws.stream!(ex_aws_config(state))
        |> Enum.to_list()
        |> Enum.filter(&(&1.key != abs_path))
        |> Enum.map(&(&1.key |> String.trim_leading(abs_path) |> String.to_charlist()))
        |> Enum.sort()

      {{:ok, objects}, state}
    rescue
      e -> Logger.error(e)
    end

    def make_dir(dir, state) do
      after_event({:make_dir, dir}, state, {:file.make_dir(user_path(dir, state)), state})
    end

    def make_symlink(_path2, _path, _state) do
      :enotsup
    end

    def open(path, [:binary, :write] = flags, state) do
      Logger.info("open[write] #{path}")
      abs_path = user_path(path, state)

      on_event({:open, {%{}, path, flags}}, state)

      {
        ExAws.S3.upload("", bucket(state), abs_path)
        |> ExAws.S3.Upload.initialize(ex_aws_config(state)),
        Keyword.put(state, :aws_upload_progress, %{index: 1, parts: []})
      }
    rescue
      e -> Logger.error(e)
    end

    def open(path, [:binary, :read] = flags, state) do
      abs_path = user_path(path, state)

      on_event({:open, {%{}, path, flags}}, state)
      op = ExAws.S3.download_file(bucket(state), abs_path, "")

      file_size = get_file_size(op.bucket, op.path, ex_aws_config(state))

      {
        {:ok, op},
        Keyword.put(state, :aws_download_state, %{position: 0, size: file_size})
      }
    rescue
      e -> Logger.error(e)
    end

    defp get_file_size(bucket, path, config) do
      %{headers: headers} =
        ExAws.S3.head_object(bucket, path)
        |> ExAws.request!(config)

      headers
      |> Enum.find(fn {k, _} -> String.downcase(k) == "content-length" end)
      |> elem(1)
      |> String.to_integer()
    end

    def position(_io_device, offs, state) do
      {{:ok, offs}, state}
    rescue
      e -> Logger.error(e)
    end

    def read(op, len, state) do
      %{position: position, size: size} = Keyword.fetch!(state, :aws_download_state)
      end_byte = min(position + len, size - 1)

      body =
        if position == size do
          :eof
        else
          {_, chunk} =
            ExAws.S3.Download.get_chunk(
              op,
              %{end_byte: end_byte, start_byte: position},
              ex_aws_config(state)
            )

          {:ok, chunk}
        end

      new_state = Keyword.put(state, :aws_download_state, %{position: end_byte + 1, size: size})

      after_event(
        {:read, %{}},
        new_state,
        {body, new_state}
      )
    rescue
      e -> Logger.error(e)
    end

    def read_link(_path, _state) do
      # read_file(path, state)
      :enotsup
    end

    def read_link_info(path, state) do
      Logger.info("read_link_info #{path}")
      read_file_info(path, state)
    end

    def read_file_info(path, state) do
      Logger.info("read file info #{path}")

      file_info =
        ExAws.S3.head_object(bucket(state), user_path(path, state) |> IO.inspect())
        |> ExAws.request(ex_aws_config(state))
        |> case do
          {:ok, %{headers: headers}} ->
            size = extract_header_value(headers, "content-length")
            type = :regular
            access = :read_write
            ctime = extract_header_value(headers, "last-modified") |> IO.inspect()
            atime = ctime
            mtime = ctime
            mode = 33188
            links = 1
            major_device = 0
            minor_device = 0
            inode = 0
            uid = 0
            gid = 0

            {:ok,
             {:file_info, size, type, access, atime, mtime, ctime, mode, links, major_device,
              minor_device, inode, uid, gid}}

          {:error, {:http_error, 404, _}} ->
            {:error, :enoent}

          error ->
            error
        end

      {file_info, state}
    rescue
      e -> Logger.error(e)
    end

    defp extract_header_value(headers, name)

    defp extract_header_value(headers, "content-length" = name) do
      Logger.info("extract_header_value")

      headers
      |> extract_header(name)
      |> String.to_integer()
    end

    defp extract_header_value(headers, "last-modified" = name) do
      headers
      |> extract_header(name)
      |> Timex.parse!("{RFC1123}")
      |> DateTime.to_naive()
      |> NaiveDateTime.to_erl()
    end

    defp extract_header(headers, name)

    defp extract_header(headers, name) do
      headers
      |> Enum.find(fn {k, _} -> String.downcase(k) == name end)
      |> elem(1)
    end

    def rename(path, path2, state) do
      after_event(
        {:rename, {path, path2}},
        state,
        {:file.rename(user_path(path, state), user_path(path2, state)), state}
      )
    end

    def write(
          upload_op,
          data,
          state
        ) do
      Logger.info("write chunk")

      {%{index: index, parts: parts}, state} = Keyword.pop!(state, :aws_upload_progress)

      chunk =
        ExAws.S3.Upload.upload_chunk(
          {data, index},
          upload_op,
          ex_aws_config(state) |> Map.to_list()
        )

      after_event(
        {:write, %{}},
        state,
        {:ok,
         Keyword.put(state, :aws_upload_progress, %{index: index + 1, parts: [chunk | parts]})}
      )
    rescue
      e -> Logger.error(e)
    end

    def write_file_info(upload_op, info, state) do
      after_event(
        {:write_file_info, {upload_op, info}},
        state,
        {{:ok, info}, state}
        # {:file.write_file_info(user_path(path, state), info), state}
      )
    end
  end
end
