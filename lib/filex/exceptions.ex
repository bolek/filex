defmodule Filex.InvalidConfigError do
  @moduledoc """
  Raised at runtime when a Server config is invalid.
  """
  defexception [:message]
end
