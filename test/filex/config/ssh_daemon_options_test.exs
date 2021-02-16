defmodule Filex.Config.SSHDaemonOptionsTest do
  use ExUnit.Case, async: true

  describe "configure/2" do
    test "given empty options" do
      assert Filex.Config.SSHDaemonOptions.configure([], []) == []
    end

    test "system_dir as binary" do
      assert Filex.Config.SSHDaemonOptions.configure([foo: "bar"], system_dir: "/path/to") == [
               {:foo, "bar"},
               {:system_dir, '/path/to'}
             ]
    end

    test "system_dir as printable charlist" do
      assert Filex.Config.SSHDaemonOptions.configure([foo: "bar"], system_dir: '/path/to') ==
               [
                 {:foo, "bar"},
                 {:system_dir, '/path/to'}
               ]
    end

    test "system_dir as not printable charlist" do
      assert_raise Filex.InvalidConfigError, fn ->
        Filex.Config.SSHDaemonOptions.configure([foo: "bar"], system_dir: 'abc' ++ [0])
      end
    end

    test "invalid system_dir" do
      assert_raise Filex.InvalidConfigError, fn ->
        Filex.Config.SSHDaemonOptions.configure([foo: "bar"], system_dir: {:boom})
      end
    end

    test "user_dir as binary" do
      assert Filex.Config.SSHDaemonOptions.configure([foo: "bar"], user_dir: "/path/to") == [
               {:foo, "bar"},
               {:user_dir, '/path/to'}
             ]
    end

    test "user_dir as printable charlist" do
      assert Filex.Config.SSHDaemonOptions.configure([foo: "bar"], user_dir: '/path/to') ==
               [
                 {:foo, "bar"},
                 {:user_dir, '/path/to'}
               ]
    end

    test "user_dir as not printable charlist" do
      assert_raise Filex.InvalidConfigError, fn ->
        Filex.Config.SSHDaemonOptions.configure([foo: "bar"], user_dir: 'abc' ++ [0])
      end
    end

    test "invalid user_dir" do
      assert_raise Filex.InvalidConfigError, fn ->
        Filex.Config.SSHDaemonOptions.configure([foo: "bar"], user_dir: {:boom})
      end
    end

    test "pwd_fun as fn/2" do
      pwd_fun = fn _user, _pass -> true end

      assert Filex.Config.SSHDaemonOptions.configure([foo: "bar"], pwdfun: pwd_fun) == [
               {:foo, "bar"},
               {:pwdfun, pwd_fun}
             ]
    end

    test "pwd_fun as fn/4" do
      pwd_fun = fn _user, _pass, _from, _state -> true end

      assert Filex.Config.SSHDaemonOptions.configure([foo: "bar"], pwdfun: pwd_fun) == [
               {:foo, "bar"},
               {:pwdfun, pwd_fun}
             ]
    end

    test "invalid pwd_fun" do
      assert_raise Filex.InvalidConfigError, fn ->
        Filex.Config.SSHDaemonOptions.configure([foo: "bar"], pwdfun: :boom)
      end
    end

    test "any option tuple" do
      assert Filex.Config.SSHDaemonOptions.configure([{:a, 1}], foo: "bar") == [
               {:a, 1},
               {:foo, "bar"}
             ]
    end
  end
end
