defmodule Filex.Config do
  @callback configure(Keyword.t(), any) :: Keyword.t()
  def new(spec) do
    spec
    |> Enum.reduce([], fn
      {module, args}, acc -> apply(module, :configure, [acc, args])
      module, acc -> apply(module, :configure, [acc, []])
    end)
  end
end
