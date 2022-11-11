defmodule Filex.Storage do
  require Logger

  def spec(adapter, options) do
    state =
      Filex.Storage.FileState.merge(options, adapter: adapter)
      |> maybe_set_users_root_dir()
      |> add_adapter_state()

    {Filex.Storage.FileHandler, state}
  end

  defp maybe_set_users_root_dir(state) do
    {adapter, adapter_args} = Filex.Storage.FileState.adapter(state)

    users_root_dir =
      Filex.Storage.FileState.get_lazy(state, :users_root_dir, fn ->
        Filex.Storage.Base.default_users_root_dir(adapter)
      end)

    adapter.make_dir(users_root_dir, adapter_args)

    Filex.Storage.FileState.put_users_root_dir(state, users_root_dir)
  end

  defp add_adapter_state(state) do
    {adapter, _} = Filex.Storage.FileState.adapter(state)
    Filex.Storage.FileState.put_adapter_state(state, Filex.Storage.Base.spec(adapter, state))
  end

  def initialize_user_file_state(state, user) do
    Logger.debug("initializing user file state")

    state
    |> set_user(user)
    |> set_user_dir()
  end

  defp set_user(state, user) do
    Filex.Storage.FileState.put_user(state, user)
  end

  defp set_user_dir(state) do
    {adapter, adapter_args} = Filex.Storage.FileState.adapter(state)
    user = Filex.Storage.FileState.user(state)
    users_root_dir = Filex.Storage.FileState.users_root_dir(state)
    user_dir = Filex.Storage.FileState.user_dir(state)

    user_dir =
      cond do
        is_nil(user_dir) ->
          Path.join(users_root_dir, user)

        is_function(user_dir) ->
          user_dir.(user)

        user_dir ->
          user_dir
      end

    adapter.make_dir(user_dir, adapter_args)

    Filex.Storage.FileState.put_user_dir(state, user_dir)
  end
end
