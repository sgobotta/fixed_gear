defmodule FixedGear.Repo.Migrations.ChangePrimaryKeysToUuid do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE users ADD COLUMN id_uuid uuid"
    execute "UPDATE users SET id_uuid = gen_random_uuid()"
    execute "ALTER TABLE users ALTER COLUMN id_uuid SET NOT NULL"

    execute "ALTER TABLE bikes ADD COLUMN id_uuid uuid"
    execute "UPDATE bikes SET id_uuid = gen_random_uuid()"
    execute "ALTER TABLE bikes ALTER COLUMN id_uuid SET NOT NULL"

    execute "ALTER TABLE users_tokens ADD COLUMN id_uuid uuid"
    execute "UPDATE users_tokens SET id_uuid = gen_random_uuid()"
    execute "ALTER TABLE users_tokens ALTER COLUMN id_uuid SET NOT NULL"

    execute "ALTER TABLE users_tokens ADD COLUMN user_id_uuid uuid"

    execute """
    UPDATE users_tokens AS token
    SET user_id_uuid = users.id_uuid
    FROM users
    WHERE token.user_id = users.id
    """

    execute "ALTER TABLE users_tokens ALTER COLUMN user_id_uuid SET NOT NULL"
    execute "ALTER TABLE users_tokens DROP CONSTRAINT users_tokens_user_id_fkey"

    execute "ALTER TABLE users DROP CONSTRAINT users_pkey"
    execute "ALTER TABLE users DROP COLUMN id"
    execute "ALTER TABLE users RENAME COLUMN id_uuid TO id"
    execute "ALTER TABLE users ADD PRIMARY KEY (id)"

    execute "ALTER TABLE bikes DROP CONSTRAINT bikes_pkey"
    execute "ALTER TABLE bikes DROP COLUMN id"
    execute "ALTER TABLE bikes RENAME COLUMN id_uuid TO id"
    execute "ALTER TABLE bikes ADD PRIMARY KEY (id)"

    execute "DROP INDEX users_tokens_user_id_index"
    execute "ALTER TABLE users_tokens DROP CONSTRAINT users_tokens_pkey"
    execute "ALTER TABLE users_tokens DROP COLUMN id"
    execute "ALTER TABLE users_tokens DROP COLUMN user_id"
    execute "ALTER TABLE users_tokens RENAME COLUMN id_uuid TO id"
    execute "ALTER TABLE users_tokens RENAME COLUMN user_id_uuid TO user_id"
    execute "ALTER TABLE users_tokens ADD PRIMARY KEY (id)"

    execute """
    ALTER TABLE users_tokens
      ADD CONSTRAINT users_tokens_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
    """

    execute "CREATE INDEX users_tokens_user_id_index ON users_tokens (user_id)"
  end

  def down do
    execute "ALTER TABLE users ADD COLUMN id_int bigint"
    execute "CREATE SEQUENCE users_id_seq"
    execute "UPDATE users SET id_int = nextval('users_id_seq')"

    execute "ALTER TABLE bikes ADD COLUMN id_int bigint"
    execute "CREATE SEQUENCE bikes_id_seq"
    execute "UPDATE bikes SET id_int = nextval('bikes_id_seq')"

    execute "ALTER TABLE users_tokens ADD COLUMN id_int bigint"
    execute "ALTER TABLE users_tokens ADD COLUMN user_id_int bigint"
    execute "CREATE SEQUENCE users_tokens_id_seq"
    execute "UPDATE users_tokens SET id_int = nextval('users_tokens_id_seq')"

    execute """
    UPDATE users_tokens AS token
    SET user_id_int = users.id_int
    FROM users
    WHERE token.user_id = users.id
    """

    execute "ALTER TABLE users_tokens DROP CONSTRAINT users_tokens_user_id_fkey"
    execute "DROP INDEX users_tokens_user_id_index"

    swap_back_to_bigint("users", "users_id_seq")
    swap_back_to_bigint("bikes", "bikes_id_seq")

    execute "ALTER TABLE users_tokens DROP CONSTRAINT users_tokens_pkey"
    execute "ALTER TABLE users_tokens DROP COLUMN id"
    execute "ALTER TABLE users_tokens DROP COLUMN user_id"
    execute "ALTER TABLE users_tokens RENAME COLUMN id_int TO id"
    execute "ALTER TABLE users_tokens RENAME COLUMN user_id_int TO user_id"
    execute "ALTER TABLE users_tokens ALTER COLUMN id SET NOT NULL"
    execute "ALTER TABLE users_tokens ALTER COLUMN user_id SET NOT NULL"
    execute "ALTER TABLE users_tokens ADD PRIMARY KEY (id)"
    execute "ALTER SEQUENCE users_tokens_id_seq OWNED BY users_tokens.id"

    execute """
    ALTER TABLE users_tokens
    ALTER COLUMN id SET DEFAULT nextval('users_tokens_id_seq')
    """

    reset_sequence("users_tokens_id_seq", "users_tokens")

    execute """
    ALTER TABLE users_tokens
      ADD CONSTRAINT users_tokens_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
    """

    execute "CREATE INDEX users_tokens_user_id_index ON users_tokens (user_id)"
  end

  defp swap_back_to_bigint(table, sequence) do
    execute "ALTER TABLE #{table} DROP CONSTRAINT #{table}_pkey"
    execute "ALTER TABLE #{table} DROP COLUMN id"
    execute "ALTER TABLE #{table} RENAME COLUMN id_int TO id"
    execute "ALTER TABLE #{table} ALTER COLUMN id SET NOT NULL"
    execute "ALTER TABLE #{table} ADD PRIMARY KEY (id)"
    execute "ALTER SEQUENCE #{sequence} OWNED BY #{table}.id"
    execute "ALTER TABLE #{table} ALTER COLUMN id SET DEFAULT nextval('#{sequence}')"
    reset_sequence(sequence, table)
  end

  defp reset_sequence(sequence, table) do
    execute """
    SELECT setval(
      '#{sequence}',
      COALESCE((SELECT MAX(id) FROM #{table}), 1),
      (SELECT MAX(id) FROM #{table}) IS NOT NULL
    )
    """
  end
end
