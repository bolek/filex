defmodule Filex.Config.Storage do
  @behaviour Filex.Config

  require Logger

  def configure(ssh_options, {adapter, config}) do
    config_with_defaults =
      [
        event_handler: fn event ->
          Logger.info("Event: #{inspect(event)}")
        end
      ]
      |> Keyword.merge(config)

    {file_handler, spec} = adapter.spec(ssh_options, config_with_defaults)

    Filex.Config.SFTPChannel.configure(ssh_options,
      file_handler: {file_handler, spec}
    )
  end

  def configure(ssh_options, adapter) do
    configure(ssh_options, {adapter, []})
  end
end
