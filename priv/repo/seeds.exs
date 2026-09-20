# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Set ADMIN_EMAIL / ADMIN_PASSWORD to override the local defaults.

alias FixedGear.Accounts
alias FixedGear.Accounts.User
alias FixedGear.Repo

email = System.get_env("ADMIN_EMAIL", "admin@localhost")
password = System.get_env("ADMIN_PASSWORD", "fixedgearadmin")

case Accounts.get_user_by_email(email) do
  %User{} ->
    IO.puts("Admin #{email} already exists")

  nil ->
    {:ok, user} = Accounts.register_user(%{email: email})

    {:ok, {user, _tokens}} =
      Accounts.update_user_password(user, %{password: password})

    user
    |> User.confirm_changeset()
    |> Repo.update!()

    IO.puts("Created admin #{email}")
end
