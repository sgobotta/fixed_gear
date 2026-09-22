# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Set ADMIN_EMAIL / ADMIN_PASSWORD. If ADMIN_PASSWORD is unset, a one-time
# secret is generated and printed (never a known default).

alias FixedGear.Accounts
alias FixedGear.Accounts.User
alias FixedGear.Repo

email = System.get_env("ADMIN_EMAIL", "admin@localhost")

password =
  case System.get_env("ADMIN_PASSWORD") do
    password when is_binary(password) and password != "" ->
      password

    _ ->
      generated =
        :crypto.strong_rand_bytes(16)
        |> Base.url_encode64(padding: false)

      IO.puts("ADMIN_PASSWORD was unset; generated #{generated}")
      generated
  end

user =
  case Accounts.get_user_by_email(email) do
    %User{hashed_password: nil} = user ->
      {:ok, {_user, _tokens}} =
        Accounts.update_user_password(user, %{password: password})

      user
      |> User.confirm_changeset()
      |> Repo.update!()

      IO.puts("Set password for existing admin #{email}")
      user

    %User{} = user ->
      IO.puts("Admin #{email} already exists")
      user

    nil ->
      {:ok, user} = Accounts.register_user(%{email: email, password: password})
      IO.puts("Created admin #{email}")
      user
  end

user
|> Ecto.Changeset.change(admin: true)
|> Repo.update!()
