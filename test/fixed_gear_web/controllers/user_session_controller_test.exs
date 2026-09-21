defmodule FixedGearWeb.UserSessionControllerTest do
  use FixedGearWeb.ConnCase, async: true

  import FixedGear.AccountsFixtures
  alias FixedGear.Accounts

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), user: user_fixture()}
  end

  describe "POST /users/log-in - email and password" do
    test "logs the user in", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ user.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_fixed_gear_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               gettext("Welcome back!")
    end

    test "redirects to login page with invalid credentials", %{
      conn: conn,
      user: user
    } do
      conn =
        post(conn, ~p"/users/log-in?mode=password", %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               gettext("Invalid email or password")

      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "redirects when the login payload is malformed", %{conn: conn} do
      conn = post(conn, ~p"/users/log-in", %{"user" => %{}})

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               gettext("Invalid email or password")

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "POST /users/log-in - magic link" do
    test "logs the user in", %{conn: conn, user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ user.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    test "confirms unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)
      refute user.confirmed_at

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               gettext("User confirmed successfully.")

      assert Accounts.get_user!(user.id).confirmed_at

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ user.email
      assert response =~ ~p"/users/settings"
      assert response =~ ~p"/users/log-out"
    end

    test "redirects to login page when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => "invalid"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               gettext("The link is invalid or it has expired.")

      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "redirects when the magic link token is malformed", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => "!!!"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               gettext("The link is invalid or it has expired.")

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "POST /users/update-password" do
    test "updates the password and logs the user in", %{conn: conn, user: user} do
      user = set_password(user)
      new_password = "new valid password"

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/users/update-password", %{
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               gettext("Password updated successfully!")

      assert Accounts.get_user_by_email_and_password(user.email, new_password)
    end

    test "redirects when sudo mode has expired", %{conn: conn, user: user} do
      user = set_password(user)
      new_password = "new valid password"

      conn =
        conn
        |> log_in_user(user,
          token_authenticated_at:
            DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> post(~p"/users/update-password", %{
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               gettext("You must re-authenticate to access this page.")

      refute Accounts.get_user_by_email_and_password(user.email, new_password)
    end

    test "redirects with an error when the password is invalid", %{
      conn: conn,
      user: user
    } do
      user = set_password(user)

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/users/update-password", %{
          "user" => %{
            "email" => user.email,
            "password" => "too short",
            "password_confirmation" => "too short"
          }
        })

      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               gettext("Could not update password.")

      assert Accounts.get_user_by_email_and_password(
               user.email,
               valid_user_password()
             )
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               gettext("Logged out successfully.")
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               gettext("Logged out successfully.")
    end
  end
end
