defmodule FixedGearWeb.UserSessionController do
  use FixedGearWeb, :controller

  alias FixedGear.Accounts
  alias FixedGearWeb.UserAuth

  def redirect_registration(conn, _params) do
    conn
    |> put_flash(:error, gettext("Registration is closed."))
    |> redirect(to: ~p"/users/log-in")
  end

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, gettext("User confirmed successfully."))
  end

  def create(conn, params) do
    create(conn, params, gettext("Welcome back!"))
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, gettext("The link is invalid or it has expired."))
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"user" => user_params}, info) do
    email = user_params["email"]
    password = user_params["password"]

    user =
      if is_binary(email) and is_binary(password) do
        Accounts.get_user_by_email_and_password(email, password)
      end

    if user do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, gettext("Invalid email or password"))
      |> put_flash(:email, email_hint(email))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  defp create(conn, _params, _info) do
    conn
    |> put_flash(:error, gettext("Invalid email or password"))
    |> redirect(to: ~p"/users/log-in")
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user

    if Accounts.sudo_mode?(user) do
      case Accounts.update_user_password(user, user_params) do
        {:ok, {_user, expired_tokens}} ->
          # disconnect all existing LiveViews with old sessions
          UserAuth.disconnect_sessions(expired_tokens)

          conn
          |> put_session(:user_return_to, ~p"/users/settings")
          |> create(params, gettext("Password updated successfully!"))

        {:error, _changeset} ->
          conn
          |> put_flash(:error, gettext("Could not update password."))
          |> redirect(to: ~p"/users/settings")
      end
    else
      conn
      |> put_flash(
        :error,
        gettext("You must re-authenticate to access this page.")
      )
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, gettext("Logged out successfully."))
    |> UserAuth.log_out_user()
  end

  defp email_hint(email) when is_binary(email), do: String.slice(email, 0, 160)
  defp email_hint(_email), do: ""
end
