defmodule FixedGearWeb.Admin.BikeLive.Index do
  use FixedGearWeb, :live_view

  alias FixedGear.Bikes
  alias FixedGear.Bikes.Bike
  alias FixedGear.Bikes.Calculations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {gettext("Bikes")}
        <:subtitle>{gettext("Edit weigh-in entries as needed.")}</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/bikes/new"} id="new-bike">
            {gettext("New bike")}
          </.button>
        </:actions>
      </.header>

      <.table id="bikes" rows={@bikes}>
        <:col :let={bike} label={gettext("Name")}>{bike.name}</:col>
        <:col :let={bike} label={gettext("Owner")}>{bike.owner}</:col>
        <:col :let={bike} label={gettext("Weight")}>
          {Calculations.format_weight(bike.weight_kg)} kg
        </:col>
        <:action :let={bike}>
          <.link
            id={"edit-bike-#{bike.id}"}
            navigate={~p"/admin/bikes/#{bike}/edit"}
          >
            {gettext("Edit")}
          </.link>
          <button
            type="button"
            id={"delete-bike-#{bike.id}"}
            class="text-error"
            phx-click="delete"
            phx-value-id={bike.id}
            data-confirm={gettext("Delete %{name}?", name: bike.name)}
          >
            {gettext("Delete")}
          </button>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Bikes"))
     |> assign(:bikes, Bikes.list_bikes())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    socket =
      case bike_for_delete(id) do
        %Bike{} = bike ->
          case Bikes.delete_bike(bike) do
            {:ok, _bike} ->
              put_flash(socket, :info, gettext("Bike deleted"))

            {:error, _reason} ->
              put_flash(socket, :error, gettext("Bike no longer exists"))
          end

        nil ->
          put_flash(socket, :error, gettext("Bike no longer exists"))
      end

    {:noreply, assign(socket, :bikes, Bikes.list_bikes())}
  end

  defp bike_for_delete(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> Bikes.get_bike(int)
      _ -> nil
    end
  end

  defp bike_for_delete(id) when is_integer(id), do: Bikes.get_bike(id)
  defp bike_for_delete(_id), do: nil
end
