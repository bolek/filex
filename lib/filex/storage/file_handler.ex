defmodule Filex.Storage.FileHandler do
  require Logger

  import Filex.Storage.FileState,
    only: [adapter: 1, user_dir: 1, put_adapter_state: 2]

  # Event Callbacks
  def after_event(event, _prev_state, {outcome, _new_state} = return) do
    Logger.debug("event: #{inspect(event)} :: #{inspect(outcome)}")

    return
  end

  def expand_path(path, state) do
    Path.join(user_dir(state), path)
    |> Path.expand()
  end

  # Helpers
  defp update_state({outcome, new_adapter_state}, prev_state) do
    {outcome, put_adapter_state(prev_state, new_adapter_state)}
  end

  # API
  def close(io_device, state) do
    {adapter, adapter_state} = adapter(state)

    {outcome, new_state} =
      adapter.close(io_device, adapter_state)
      |> update_state(state)

    after_event({:close, io_device}, state, {outcome, new_state})
  end

  def delete(path, state) do
    {adapter, adapter_state} = adapter(state)
    abs_path = expand_path(path, state)

    {outcome, new_state} =
      adapter.delete(abs_path, adapter_state)
      |> update_state(state)

    after_event({:delete, path}, state, {outcome, new_state})
  end

  def del_dir(path, state) do
    {adapter, adapter_state} = adapter(state)
    abs_path = expand_path(path, state)

    {outcome, new_state} =
      adapter.del_dir(abs_path, adapter_state)
      |> update_state(state)

    after_event({:del_dir, path}, state, {outcome, new_state})
  end

  def get_cwd(state) do
    {adapter, adapter_state} = adapter(state)

    {outcome, new_state} =
      adapter.get_cwd(adapter_state)
      |> update_state(state)

    {outcome, new_state}
  end

  def is_dir(path, state) do
    {adapter, adapter_state} = adapter(state)
    abs_path = expand_path(path, state)

    {outcome, new_state} =
      adapter.is_dir(abs_path, adapter_state)
      |> update_state(state)

    {outcome, new_state}
  end

  def list_dir(path, state) do
    {adapter, adapter_state} = adapter(state)
    abs_path = expand_path(path, state)

    {outcome, new_state} =
      adapter.list_dir(abs_path, adapter_state)
      |> update_state(state)

    after_event({:list_dir, path}, state, {outcome, new_state})
  end

  def make_dir(path, state) do
    {adapter, adapter_state} = adapter(state)
    abs_path = expand_path(path, state)

    {outcome, new_state} =
      adapter.make_dir(abs_path, adapter_state)
      |> update_state(state)

    after_event({:make_dir, path}, state, {outcome, new_state})
  end

  def make_symlink(path, state) do
    {adapter, adapter_state} = adapter(state)
    abs_path = expand_path(path, state)

    {outcome, new_state} =
      adapter.make_symlink(abs_path, adapter_state)
      |> update_state(state)

    after_event({:make_synlink, path}, state, {outcome, new_state})
  end

  def open(path, flags, state) do
    {adapter, adapter_state} = adapter(state)
    abs_path = expand_path(path, state)

    {outcome, new_state} =
      adapter.open(abs_path, flags, adapter_state)
      |> update_state(state)

    after_event({:open, path, flags}, state, {outcome, new_state})
  end

  def position(io_device, offset, state) do
    {adapter, adapter_state} = adapter(state)

    adapter.position(io_device, offset, adapter_state)
    |> update_state(state)
  end

  def read(io_device, length, state) do
    {adapter, adapter_state} = adapter(state)

    adapter.read(io_device, length, adapter_state)
    |> update_state(state)
  end

  def read_link(path, state) do
    {adapter, adapter_state} = adapter(state)
    abs_path = expand_path(path, state)

    adapter.read_link(abs_path, adapter_state)
    |> update_state(state)
  end

  def read_link_info(path, state) do
    {adapter, adapter_state} = adapter(state)
    abs_path = expand_path(path, state)

    adapter.read_link_info(abs_path, adapter_state)
    |> update_state(state)
  end

  def read_file_info(path, state) do
    {adapter, adapter_state} = adapter(state)
    abs_path = expand_path(path, state)

    adapter.read_file_info(abs_path, adapter_state)
    |> update_state(state)
  end

  def rename(from_path, to_path, state) do
    {adapter, adapter_state} = adapter(state)
    abs_from_path = expand_path(from_path, state)
    abs_to_path = expand_path(to_path, state)

    {outcome, new_state} =
      adapter.rename(abs_from_path, abs_to_path, adapter_state)
      |> update_state(state)

    after_event({:rename, from_path, to_path}, state, {outcome, new_state})
  end

  def write(io_device, data, state) do
    {adapter, adapter_state} = adapter(state)

    adapter.write(io_device, data, adapter_state)
    |> update_state(state)
  end

  def write_file_info(path, info, state) do
    {adapter, adapter_state} = adapter(state)
    abs_path = expand_path(path, state)

    {outcome, new_state} =
      adapter.write_file_info(abs_path, info, adapter_state)
      |> update_state(state)

    after_event({:write_file_info, path}, state, {outcome, new_state})
  end
end
