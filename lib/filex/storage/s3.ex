defmodule Filex.Storage.S3 do
  require Logger

  # Spec
  def spec(options) do
    if is_nil(options[:bucket]) do
      raise "AWS bucket not configured for S3 storage."
    end

    [
      aws_config: ExAws.Config.new(:s3, options),
      bucket: options[:bucket]
    ]
  end

  def default_users_root_dir() do
    "/"
  end

  defp aws_config(state), do: state[:aws_config]
  defp bucket(state), do: state[:bucket]

  def request(op, state) do
    ExAws.request(op, aws_config(state))
  end

  # File Handler API

  def close(%ExAws.S3.Upload{} = upload_op, state) do
    parts =
      Keyword.get(state, :aws_upload_progress)
      |> Map.fetch!(:parts)

    outcome =
      case Enum.find(parts, fn
             {:error, _} -> true
             _ -> false
           end) do
        nil ->
          ExAws.S3.Upload.complete(parts, upload_op, aws_config(state))
          Keyword.delete(state, :aws_upload_progress)

        error ->
          error
      end

    {outcome, state}
  end

  def close(_io_device, state) do
    {:ok, state}
  end

  def delete(path, state) do
    result =
      bucket(state)
      |> ExAws.S3.delete_object(path)
      |> ExAws.request(aws_config(state))
      |> case do
        {:ok, _} -> :ok
        error -> error
      end

    {result, state}
  end

  def del_dir(path, state) do
    path = String.trim(path, "/")

    stream =
      ExAws.S3.list_objects(bucket(state), prefix: path)
      |> ExAws.stream!(aws_config(state))
      |> Stream.map(& &1.key)

    ExAws.S3.delete_all_objects(bucket(state), stream) |> request(state)

    {:ok, state}
  end

  def get_cwd(state) do
    {{:ok, "/"}, state}
  end

  def is_dir(path, state)

  def is_dir("/", state) do
    {true, state}
  end

  def is_dir(path, state) do
    request =
      bucket(state)
      |> ExAws.S3.get_object(path)

    is_dir =
      request
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
      {{:error, e}, state}
  end

  def list_dir(path, state) do
    path = String.trim(path, "/") <> "/"

    objects =
      bucket(state)
      |> ExAws.S3.list_objects(
        delimiter: "/",
        prefix: path
      )
      |> ExAws.stream!(aws_config(state))
      |> Enum.to_list()
      |> Enum.filter(&(&1.key != path))
      |> Enum.map(&(&1.key |> String.trim_leading(path) |> String.to_charlist()))
      |> Enum.sort()

    {{:ok, objects}, state}
  rescue
    e -> Logger.error(e)
  end

  def make_dir(path, state) do
    outcome =
      Path.split(path)
      |> Enum.reduce_while("/", fn dir, parent ->
        interim_path = Path.join(parent, dir)

        is_dir(interim_path, state)
        |> case do
          {true, _} ->
            {:cont, interim_path}

          {false, _} ->
            bucket(state)
            |> ExAws.S3.put_object(interim_path, "",
              content_type: "application/x-directory; charset=UTF-8"
            )
            |> request(state)
            |> case do
              {:ok, _} -> {:cont, interim_path}
              {:error, error} -> {:halt, {:error, error}}
            end
        end
      end)
      |> case do
        {:error, _} = error -> error
        _ -> :ok
      end

    {outcome, state}
  end

  def make_symlink(_path_1, _path_2, state) do
    {{:error, :enotsup}, state}
  end

  def open(path, [:binary, :read], state) do
    op = ExAws.S3.download_file(bucket(state), path, "")

    file_size = get_file_size(op.bucket, op.path, aws_config(state))

    new_state = Keyword.put(state, :aws_download_state, %{position: 0, size: file_size})

    {{:ok, op}, new_state}
  rescue
    e -> Logger.error(e)
  end

  def open(path, [:binary, :write], state) do
    {
      ExAws.S3.upload("", bucket(state), path)
      |> ExAws.S3.Upload.initialize(aws_config(state)),
      Keyword.put(state, :aws_upload_progress, %{index: 1, parts: []})
    }
  rescue
    e ->
      {{:error, e}, state}
  end

  def position(_io_device, offs, state) do
    # new_state = Keyword.put(state, :aws_download_state, %{position: 0, size: file_size})
    {{:ok, offs}, state}
  rescue
    e -> Logger.error(e)
  end

  def read(op, len, state) do
    %{position: position, size: size} = Keyword.fetch!(state, :aws_download_state)
    end_byte = min(position + len, size - 1)

    outcome =
      if position == size do
        :eof
      else
        {_, chunk} =
          ExAws.S3.Download.get_chunk(
            op,
            %{end_byte: end_byte, start_byte: position},
            aws_config(state)
          )

        {:ok, chunk}
      end

    new_state = Keyword.put(state, :aws_download_state, %{position: end_byte + 1, size: size})

    {outcome, new_state}
  rescue
    e ->
      Logger.error(e)
      {{:error, e}, state}
  end

  def read_link(_path, state) do
    {{:error, :einval}, state}
  end

  def read_link_info(path, state) do
    read_file_info(path, state)
  end

  def read_file_info(path, state) do
    file_info =
      ExAws.S3.head_object(bucket(state), path)
      |> request(state)
      |> case do
        {:ok, %{headers: headers}} ->
          size = extract_header_value(headers, "content-length")
          type = extract_file_type_from_headers(headers)
          access = :read_write
          ctime = extract_header_value(headers, "last-modified")
          atime = ctime
          mtime = ctime

          mode =
            case type do
              # file with 522 permissions
              :regular -> 33188
              # directory with 755 permissions
              :directory -> 16877
            end

          links = 0
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

  def rename(path, path2, state) do
    ExAws.S3.put_object_copy(
      bucket(state),
      path2,
      bucket(state),
      path
    )
    |> request(state)

    ExAws.S3.delete_object(bucket(state), path)
    |> request(state)

    {:ok, state}
  end

  # write file
  def write(
        upload_op,
        data,
        state
      ) do
    {%{index: index, parts: parts}, state} = Keyword.pop!(state, :aws_upload_progress)

    chunk =
      ExAws.S3.Upload.upload_chunk(
        {data, index},
        upload_op,
        aws_config(state) |> Map.to_list()
      )

    new_state =
      Keyword.put(state, :aws_upload_progress, %{index: index + 1, parts: [chunk | parts]})

    {:ok, new_state}
  rescue
    e ->
      Logger.error(e)
      {{:error, e}, state}
  end

  # write file info
  def write_file_info(_upload_op, _info, state) do
    {{:error, :not_supported}, state}
  end

  # Helpers

  defp get_file_size(bucket, path, config) do
    %{headers: headers} =
      ExAws.S3.head_object(bucket, path)
      |> ExAws.request!(config)

    headers
    |> Enum.find(fn {k, _} -> String.downcase(k) == "content-length" end)
    |> elem(1)
    |> String.to_integer()
  end

  defp extract_file_type_from_headers(headers) do
    headers
    |> extract_header("content-type")
    |> String.split(";")
    |> List.first()
    |> String.downcase()
    |> case do
      "application/x-directory" -> :directory
      _ -> :regular
    end
  end

  defp extract_header_value(headers, name)

  defp extract_header_value(headers, "content-length" = name) do
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
