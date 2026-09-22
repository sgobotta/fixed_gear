defmodule FixedGear.Bikes do
  @moduledoc """
  Weigh-in bikes and ranking queries.
  """

  use Gettext, backend: FixedGearWeb.Gettext

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

  # "t" is the English abbreviation for tooth. Spanish uses "d" (diente).
  def tooth_suffix, do: gettext("t")

  def tooth_label(count) when is_integer(count), do: "#{count}#{tooth_suffix()}"

  def chain_ring_options do
    Enum.map(
      Calculations.chain_ring_min()..Calculations.chain_ring_max(),
      fn teeth -> {tooth_label(teeth), teeth} end
    )
  end

  def sprocket_options do
    Enum.map(
      Calculations.sprocket_min()..Calculations.sprocket_max(),
      fn teeth -> {tooth_label(teeth), teeth} end
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

  def get_bike(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} ->
        Bike
        |> from(as: :bike)
        |> where([bike: b], b.id == ^id)
        |> select_list_fields()
        |> Repo.one()

      :error ->
        nil
    end
  end

  def get_bike!(id) do
    case get_bike(id) do
      nil -> raise Ecto.NoResultsError, queryable: Bike
      bike -> bike
    end
  end

  def get_bike_photo(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} ->
        from(b in Bike,
          where: b.id == ^id and not is_nil(b.photo),
          select: {b.photo, b.photo_content_type}
        )
        |> Repo.one()

      :error ->
        nil
    end
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

  def delete_bike(%Bike{id: nil}), do: {:error, :missing}

  def delete_bike(%Bike{} = bike) do
    Repo.delete(bike)
  rescue
    Ecto.StaleEntryError -> {:error, :stale}
  end

  defp select_list_fields(query) do
    select(query, [bike: b], struct(b, ^@list_fields))
  end
end
