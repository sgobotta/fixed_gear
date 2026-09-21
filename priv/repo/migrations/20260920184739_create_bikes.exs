defmodule FixedGear.Repo.Migrations.CreateBikes do
  use Ecto.Migration

  def change do
    create table(:bikes) do
      add :name, :string, null: false
      add :owner, :string, null: false
      add :weight_kg, :decimal, precision: 8, scale: 3, null: false
      add :frame_material, :string
      add :frame_name, :string
      add :handlebar_material, :string
      add :chain_ring, :integer
      add :rear_sprocket, :integer
      add :tire_width, :integer
      add :photo, :binary
      add :photo_content_type, :string

      timestamps(type: :utc_datetime)
    end

    create index(:bikes, [:weight_kg])
  end
end
