defmodule FixedGearWeb.UserLive.RegistrationTest do
  use FixedGearWeb.ConnCase, async: true

  import FixedGear.AccountsFixtures

  test "redirects visitors to log in", %{conn: conn} do
    conn = get(conn, ~p"/users/register")

    assert redirected_to(conn) == ~p"/users/log-in"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             gettext("Registration is closed.")
  end

  test "redirects authenticated users to log in", %{conn: conn} do
    conn =
      conn
      |> log_in_user(user_fixture())
      |> get(~p"/users/register")

    assert redirected_to(conn) == ~p"/users/log-in"
  end
end
