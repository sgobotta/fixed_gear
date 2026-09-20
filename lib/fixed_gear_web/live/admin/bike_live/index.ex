defmodule FixedGearWeb.Admin.BikeLive.Index do
  use FixedGearWeb, :live_view

  alias FixedGear.Bikes
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
end
