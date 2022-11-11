defmodule Filex.Storage.Base do
  def default_users_root_dir(adapter) do
    adapter.default_users_root_dir()
  end

  def spec(adapter, options) do
    adapter.spec(options)
  end
end
