defmodule Filex.Config.ShellTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "configure/2" do
    test "given no options" do
      assert capture_log(fn ->
               assert Filex.Config.Shell.configure([foo: "bar"], []) == [foo: "bar"]
             end) =~ "Provided empty shell config. Skipping."
    end

    test "given a fn/2" do
      shell_fn = fn _user, _from -> :ok end

      assert Filex.Config.Shell.configure([{:foo, "bar"}], shell_fn) == [
               {:foo, "bar"},
               {:shell, shell_fn}
             ]
    end

    test "given an invalid option" do
      assert_raise(Filex.InvalidConfigError, fn ->
        Filex.Config.Shell.configure([{:foo, "bar"}], "boom")
      end)
    end
  end
end
