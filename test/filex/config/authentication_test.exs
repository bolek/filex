defmodule Filex.Config.AuthenticationTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Filex.Config.Authentication

  describe "configure/2" do
    test "given auth/2 function" do
      auth_fun = fn _user, _pass -> true end

      assert Authentication.configure([{:foo, "bar"}], auth_fun) == [
               {:foo, "bar"},
               {:pwdfun, auth_fun}
             ]
    end

    test "given auth/4 function" do
      auth_fun = fn _user, _pass, _peer_address, _state -> true end
      assert Authentication.configure([], auth_fun) == [{:pwdfun, auth_fun}]
    end

    test "given list of user/passwords" do
      credentials = [{'lynx', 'test'}]
      assert Authentication.configure([], credentials) == [{:user_passwords, credentials}]
    end

    test "given list of user/passwords as strings" do
      credentials = [{"lynx", "test"}]
      assert Authentication.configure([], credentials) == [{:user_passwords, [{'lynx', 'test'}]}]
    end

    test "given something else option" do
      assert capture_log(fn ->
               assert Authentication.configure([], "boom") == []
             end) =~
               "No such setting option for authentication. Skipping config. Check documentation."
    end
  end
end
