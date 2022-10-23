defmodule Filex.Storage.S3 do
  require Logger

  def spec(_ssh_options, options) do
    {event_handler, options} = Keyword.pop!(options, :event_handler)

    {Filex.Storage.S3.FileHandler,
     event_handler: event_handler,
     root_path: '/',
     cwd: '/',
     aws_config: Filex.Storage.S3.Config.new(options)}
  end

  defmodule FileHandler do
    # operations

    # open a file
    def open(path, [:binary, :write] = flags, state) do
      on_event({:open, {nil, path, flags}}, state)

      abs_path = user_path(path, state)

      {
        ExAws.S3.upload("", bucket(state), abs_path)
        |> ExAws.S3.Upload.initialize(ex_aws_config(state)),
        Keyword.put(state, :aws_upload_progress, %{index: 1, parts: []})
      }
    rescue
      e ->
        Logger.error(e)
    end

    def open(path, [:binary, :read] = flags, state) do
      on_event({:open, {nil, path, flags}}, state)

      abs_path = user_path(path, state)

      op = ExAws.S3.download_file(bucket(state), abs_path, "")

      file_size = get_file_size(op.bucket, op.path, ex_aws_config(state))

      {
        {:ok, op},
        Keyword.put(state, :aws_download_state, %{position: 0, size: file_size})
      }
    rescue
      e -> Logger.error(e)
    end

    # read file
    def read(op, len, state) do
      Logger.info("read/3")
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

    # read file info
    def read_file_info(path, state) do
      Logger.info("read_file_info/2")
      Logger.info("read file info #{path}")

      file_info =
        ExAws.S3.head_object(bucket(state), user_path(path, state))
        |> request(state)
        |> case do
          {:ok, %{headers: headers}} ->
            size = extract_header_value(headers, "content-length")
            type = :regular
            access = :read_write
            ctime = extract_header_value(headers, "last-modified")
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

    # rename / move file
    def rename(path, path2, state) do
      Logger.info("rename/3")

      after_event(
        {:rename, {path, path2}},
        state,
        {:file.rename(user_path(path, state), user_path(path2, state)), state}
      )
    end

    # write file
    def write(
          upload_op,
          data,
          state
        ) do
      Logger.info("write/3")
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

    # write file info
    def write_file_info(upload_op, info, state) do
      Logger.info("write_file_info/3")

      after_event(
        {:write_file_info, {upload_op, info}},
        state,
        {{:ok, info}, state}
      )
    end

    # close a file
    def close(%ExAws.S3.Upload{} = upload_op, state) do
      Logger.info("close/1")

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

    # delete a file
    def delete(rel_path, state) do
      Logger.info("delete/2")

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

    # list directory
    def list_dir(rel_path, state) do
      Logger.info("list dir: #{inspect(rel_path)}")

      abs_path = user_path(rel_path, state)

      abs_path =
        if String.ends_with?(abs_path, "/") do
          abs_path
        else
          abs_path <> "/"
        end

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

    # make directory
    def make_dir(path, state) do
      path = to_string(path)
      Logger.info("make_dir/2 - #{path}")

      abs_dir = user_path(path, state)

      bucket(state)
      |> ExAws.S3.put_object(abs_dir, "", content_type: "application/x-directory; charset=UTF-8")
      |> request(state)

      after_event({:make_dir, path}, state, {:ok, state})
    end

    # delete a directory
    def del_dir(path, state) do
      Logger.info("del_dir/1")

      stream =
        ExAws.S3.list_objects(bucket(state), prefix: user_path(path, state))
        |> ExAws.stream!(ex_aws_config(state))
        |> Stream.map(& &1.key)

      ExAws.S3.delete_all_objects(bucket(state), stream) |> request(state)

      after_event({:del_dir, path}, state, {:ok, state})
    end

    # make symlink
    def make_symlink(path2, path, state) do
      Logger.info("make_synlink/3")

      after_event(
        {:make_symlink, {path2, path}},
        state,
        {{:error, :enotsup}, user_path(path, state), state}
      )
    end

    # read link - not supported
    def read_link(path, state) do
      Logger.info("read_link/2 #{path}")
      {{:error, :einval}, state}
    end

    # read link info - not supported
    def read_link_info(path, state) do
      read_file_info(path, state)
    end

    # event hooks
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
      Logger.debug(
        "after_event:: param: #{inspect(param)}, state: #{inspect(state)}, result: #{inspect(result)}"
      )

      on_event(param, state)
      result
    end

    # helper functions

    defp aws_config(state) do
      # Logger.info("aws_config/1")
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

    defp user_root_path(state) do
      state[:root_path]
    end

    defp user_path(path, state) do
      Logger.info("user_path/2 ; #{path}")

      Path.join(user_root_path(state), path)
      |> String.trim_leading("/")
      |> String.trim_trailing(".")
    end

    defp user(state) do
      Logger.info("user/1")

      Keyword.get(state, :user, :anonymous) |> to_string
    end

    def ensure_dir(path) do
      Logger.info("ensure_dir/1")

      {:ok, path}
    end

    def get_cwd(state) do
      Logger.info("get_cwd/1")

      cwd =
        Keyword.get(
          state,
          :cwd,
          user_path(".", state)
          |> case do
            "" -> "/"
            path -> path
          end
          |> String.to_charlist()
        )

      {{:ok, cwd}, state}
    end

    def is_dir(rel_path, state)

    def is_dir('/', state) do
      Logger.info("is_dir/1")
      {true, state}
    end

    def is_dir(rel_path, state) do
      Logger.info("is dir: #{rel_path}")
      Logger.info(user_path(rel_path, state))

      is_dir =
        bucket(state)
        |> ExAws.S3.get_object(user_path(rel_path, state))
        |> request(state)
        |> case do
          {:ok, %{headers: headers, status_code: 200}} ->
            Enum.any?(headers, fn
              {"content-type", "application/x-directory; charset=UTF-8"} -> true
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

    def request(op, state) do
      Logger.metadata(user: Keyword.get(state, :user, :anonymous) |> to_string())
      Logger.info("request/2")
      aws_config = ex_aws_config(state)

      op
      |> ExAws.request(aws_config)
    end

    defp get_file_size(bucket, path, config) do
      Logger.info("get_file_size/3")

      %{headers: headers} =
        ExAws.S3.head_object(bucket, path)
        |> ExAws.request!(config)

      headers
      |> Enum.find(fn {k, _} -> String.downcase(k) == "content-length" end)
      |> elem(1)
      |> String.to_integer()
    end

    def position(_io_device, offs, state) do
      Logger.info("partition/3")
      {{:ok, offs}, state}
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
  end
end
