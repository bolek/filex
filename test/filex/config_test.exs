defmodule Filex.ConfigTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "given empty spec" do
      assert Filex.Config.new([]) == []
    end

    test "given valid spec builds config" do
      spec = [
        {Filex.Config.SSHDaemonOptions, [system_dir: "system/path"]}
      ]

      assert Filex.Config.new(spec) == [system_dir: 'system/path']
    end
  end
end
