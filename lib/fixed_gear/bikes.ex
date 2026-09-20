defmodule FixedGear.Bikes do
  @moduledoc """
  Weigh-in bikes and ranking queries.
  """

  import Ecto.Query, warn: false

  alias FixedGear.Bikes.Bike
  alias FixedGear.Bikes.Calculations
  alias FixedGear.Repo

  @list_fields [
    :id,
    :name,
    :owner,
    :weight_kg,
    :frame_material,
    :frame_name,
    :handlebar_material,
    :chain_ring,
    :rear_sprocket,
    :tire_width,
    :photo_content_type,
    :inserted_at,
    :updated_at
  ]

  defdelegate materials(), to: Calculations
  defdelegate tire_widths(), to: Calculations

  def material_options do
    Enum.map(Calculations.materials(), fn material ->
      {Calculations.material_label(material), material}
    end)
  end

  def tire_options do
    Enum.map(Calculations.tire_widths(), fn width ->
      {Calculations.tire_label(width), width}
    end)
  end

  def chain_ring_options do
    Enum.map(
      Calculations.chain_ring_min()..Calculations.chain_ring_max(),
      fn teeth -> {"#{teeth}t", teeth} end
    )
  end

  def sprocket_options do
    Enum.map(
      Calculations.sprocket_min()..Calculations.sprocket_max(),
      fn teeth -> {"#{teeth}t", teeth} end
    )
  end

  def list_bikes do
    Bike
    |> from(as: :bike)
    |> select_list_fields()
    |> order_by([bike: b], desc: b.inserted_at)
    |> Repo.all()
  end

  def list_bikes_by_weight do
    Bike
    |> from(as: :bike)
    |> select_list_fields()
    |> order_by([bike: b], asc: b.weight_kg, asc: b.inserted_at)
    |> Repo.all()
  end

  def get_bike!(id) do
    Bike
    |> from(as: :bike)
    |> where([bike: b], b.id == ^id)
    |> select_list_fields()
    |> Repo.one!()
  end

  def get_bike_photo(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> get_bike_photo(int)
      _ -> nil
    end
  end

  def get_bike_photo(id) when is_integer(id) do
    from(b in Bike,
      where: b.id == ^id and not is_nil(b.photo),
      select: {b.photo, b.photo_content_type}
    )
    |> Repo.one()
  end

  def change_bike(%Bike{} = bike, attrs \\ %{}) do
    Bike.changeset(bike, attrs)
  end

  def create_bike(attrs, photo \\ nil) do
    %Bike{}
    |> Bike.changeset(attrs)
    |> Bike.put_photo(photo)
    |> Repo.insert()
  end

  def update_bike(%Bike{} = bike, attrs, photo \\ nil) do
    bike
    |> Bike.changeset(attrs)
    |> Bike.put_photo(photo)
    |> Repo.update()
  end

  def delete_bike(%Bike{} = bike) do
    Repo.delete(bike)
  end

  defp select_list_fields(query) do
    select(query, [bike: b], struct(b, ^@list_fields))
  end
end
