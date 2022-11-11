defmodule Filex.Config.Storage do
  @behaviour Filex.Config

  require Logger

  def configure(ssh_options, {adapter, options}) do
    options_with_defaults =
      [
        event_handler: fn event ->
          nil
        end
      ]
      |> Keyword.merge(options)

    Filex.Config.SFTPChannel.configure(ssh_options,
      file_handler: Filex.Storage.spec(adapter, options_with_defaults)
    )
  end

  def configure(ssh_options, adapter) do
    configure(ssh_options, {adapter, []})
  end
end
