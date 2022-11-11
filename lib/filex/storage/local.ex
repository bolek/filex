defmodule Filex.Storage.Local do
  require Logger

  def spec(_options) do
    []
  end

  def default_users_root_dir() do
    Filex.Utils.tmp_dir!()
  end

  # File Handler API

  def close(io_device, state) do
    {:file.close(io_device), state}
  end

  def delete(path, state) do
    {:file.delete(path), state}
  end

  def del_dir(path, state) do
    {:file.del_dir_r(path), state}
  end

  def get_cwd(state) do
    {:file.get_cwd(), state}
  end

  def is_dir(path, state) do
    {:filelib.is_dir(path), state}
  end

  def list_dir(path, state) do
    {:file.list_dir(path), state}
  end

  def make_dir(dir, state) do
    {:file.make_dir(dir), state}
  end

  def make_symlink(path2, path, state) do
    {:file.make_symlink(path2, path), state}
  end

  def open(path, flags, state) do
    {:file.open(path, flags), state}
  end

  def position(io_device, offs, state) do
    {:file.position(io_device, offs), state}
  end

  def read(io_device, len, state) do
    {:file.read(io_device, len), state}
  end

  def read_link(path, state) do
    {:file.read_link(path), state}
  end

  def read_link_info(path, state) do
    {:file.read_link_info(path), state}
  end

  def read_file_info(path, state) do
    {:file.read_file_info(path), state}
  end

  def rename(from_path, to_path, state) do
    {:file.rename(from_path, to_path), state}
  end

  def write(io_device, data, state) do
    {:file.write(io_device, data), state}
  end

  def write_file_info(path, info, state) do
    {:file.write_file_info(path, info), state}
  end

  def make_dir!(path) do
    if !File.exists?(path), do: File.mkdir_p!(path)

    path
  end
end
