defmodule Filex.Utils do
  def create_tmp_dir(prefix \\ "Filex") do
    time = System.os_time()
    partial = "#{prefix}-#{time}"

    dir =
      System.tmp_dir!()
      |> Path.join(partial)

    File.mkdir_p(dir)

    dir
  end

  def create_host_key(key_path) do
    {_, 0} = System.cmd("ssh-keygen", ["-m", "PEM", "-t", "rsa", "-N", "", "-f", key_path])
    :ok
  end

  def to_charlist!(value) when is_binary(value), do: String.to_charlist(value)

  def to_charlist!(value) when is_list(value) do
    if List.ascii_printable?(value) do
      value
    else
      raise "Expecting a string or printable charlist"
    end
  end
end
