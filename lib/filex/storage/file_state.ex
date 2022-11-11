defmodule Filex.Storage.FileState do
  def merge(a, b) do
    Keyword.merge(a, b)
  end

  def get_lazy(state, field, fun) do
    Keyword.get_lazy(state, field, fun)
  end

  def put(state, field, value) do
    List.keystore(state, field, 0, {field, value})
  end

  def put_adapter_state(state, value) do
    put(state, :adapter_state, value)
  end

  def put_user(state, value) do
    put(state, :user, value)
  end

  def put_user_dir(state, value) do
    put(state, :user_dir, value)
  end

  def put_users_root_dir(state, value) do
    put(state, :users_root_dir, value)
  end

  def adapter(state), do: {state[:adapter], state[:adapter_state]}

  def user(state), do: state[:user]
  def users_root_dir(state), do: state[:users_root_dir]
  def user_dir(state), do: state[:user_dir]
end
