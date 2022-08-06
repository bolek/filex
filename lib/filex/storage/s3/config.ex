defmodule Filex.Storage.S3.Config do
  @moduledoc false
  defstruct ex_aws: %{}, bucket: nil

  def new(options) do
    %__MODULE__{
      ex_aws: ExAws.Config.new(:s3, options),
      bucket: Keyword.get(options, :bucket)
    }
  end

  def bucket(config), do: config.bucket

  def ex_aws_config(config), do: config.ex_aws
end
