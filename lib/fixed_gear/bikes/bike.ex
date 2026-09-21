defmodule FixedGear.Bikes.Bike do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias FixedGear.Bikes.Calculations
  alias FixedGear.Bikes.Photo

  @materials Calculations.materials()
  @tire_widths Calculations.tire_widths()
  @optional [
    :frame_material,
    :frame_name,
    :handlebar_material,
    :chain_ring,
    :rear_sprocket,
    :tire_width
  ]

  schema "bikes" do
    field :name, :string
    field :owner, :string
    field :weight_kg, :decimal
    field :frame_material, Ecto.Enum, values: @materials
    field :frame_name, :string
    field :handlebar_material, Ecto.Enum, values: @materials
    field :chain_ring, :integer
    field :rear_sprocket, :integer
    field :tire_width, :integer
    field :photo, :binary
    field :photo_content_type, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(bike, attrs) do
    bike
    |> cast(nilify_blanks(attrs), [
      :name,
      :owner,
      :weight_kg | @optional
    ])
    |> validate_required([:name, :owner, :weight_kg])
    |> validate_length(:name, min: 1, max: 160)
    |> validate_length(:owner, min: 1, max: 160)
    |> validate_length(:frame_name, max: 160)
    |> validate_number(:weight_kg, greater_than: 0)
    |> round_weight()
    |> validate_number(:chain_ring,
      greater_than_or_equal_to: Calculations.chain_ring_min(),
      less_than_or_equal_to: Calculations.chain_ring_max()
    )
    |> validate_number(:rear_sprocket,
      greater_than_or_equal_to: Calculations.sprocket_min(),
      less_than_or_equal_to: Calculations.sprocket_max()
    )
    |> validate_inclusion(:tire_width, @tire_widths)
  end

  def put_photo(changeset, {data, _claimed_type}) when is_binary(data) do
    case Photo.identify(data) do
      {:ok, content_type} ->
        changeset
        |> put_change(:photo, data)
        |> put_change(:photo_content_type, content_type)

      :error ->
        add_error(changeset, :photo, "must be a JPEG, PNG, or WebP")
    end
  end

  def put_photo(changeset, _), do: changeset

  def photo?(bike), do: not is_nil(bike.photo_content_type)

  defp round_weight(changeset) do
    case get_change(changeset, :weight_kg) do
      %Decimal{} = weight ->
        put_change(changeset, :weight_kg, Decimal.round(weight, 3))

      _ ->
        changeset
    end
  end

  defp nilify_blanks(attrs) when is_map(attrs) do
    attrs = stringify_keys(attrs)

    Enum.reduce(@optional, attrs, fn field, acc ->
      key = Atom.to_string(field)

      if Map.has_key?(acc, key) and blank?(acc[key]) do
        Map.put(acc, key, nil)
      else
        acc
      end
    end)
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp blank?(value), do: value in [nil, ""]
end
