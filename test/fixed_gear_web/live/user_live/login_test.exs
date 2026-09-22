defmodule FixedGearWeb.UserLive.LoginTest do
  use FixedGearWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FixedGear.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ gettext("Log in")
      refute html =~ "Sign up"
      assert html =~ gettext("Log in with email")
    end
  end

  describe "user login - magic link" do
    test "sends magic link email when user exists", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~
               gettext(
                 "If your email is in our system, you will receive instructions for logging in shortly."
               )

      assert FixedGear.Repo.get_by!(FixedGear.Accounts.UserToken,
               user_id: user.id
             ).context ==
               "login"
    end

    test "does not disclose if user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~
               gettext(
                 "If your email is in our system, you will receive instructions for logging in shortly."
               )
    end
  end

  describe "user login - password" do
    test "redirects if user logs in with valid credentials", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{
            email: user.email,
            password: valid_user_password(),
            remember_me: true
          }
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/ranking/weight"
    end

    test "redirects to login page with a flash error if credentials are invalid",
         %{
           conn: conn
         } do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{email: "test@email.com", password: "123456"}
        )

      conn = submit_form(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               gettext("Invalid email or password")

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "login navigation" do
    test "does not expose registration from the login page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/users/log-in")

      refute html =~ "Sign up"
      refute has_element?(lv, "a", "Sign up")
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows login page with email filled in", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~
               gettext(
                 "You need to reauthenticate to perform sensitive actions on your account."
               )

      refute html =~ "Register"
      assert html =~ gettext("Log in with email")

      assert html =~
               ~s(<input type="email" name="user[email]" id="login_form_magic_email" value="#{user.email}")
    end
  end
end
