defmodule FixedGearWeb.SkidPatchLive do
  use FixedGearWeb, :live_view

  alias FixedGear.Bikes
  alias FixedGear.Bikes.Calculations
  alias FixedGearWeb.CadenceColor

  @default_ring 48
  @default_cog 16
  @default_tire 28

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      section={:skid_patch}
    >
      <section class="space-y-6">
        <header class="space-y-2">
          <p class="text-xs font-semibold tracking-[0.25em] text-base-content/50 uppercase">
            {gettext("Playground")}
          </p>
          <h1 class="text-3xl font-semibold tracking-tight sm:text-4xl">
            {gettext("Skid Patch")}
          </h1>
          <p class="max-w-md text-sm text-base-content/65">
            {gettext(
              "Play with chainring, sprocket, and tire to see development, ratio, speed, and skid patches."
            )}
          </p>
        </header>

        <.form
          for={@form}
          id="skid-patch-form"
          phx-change="update"
          class="space-y-5 rounded-3xl border border-base-300 bg-base-100 p-4 shadow-sm sm:p-5"
        >
          <div class="space-y-4">
            <.gear_slider
              id="chain-ring-slider"
              input_id="chain-ring"
              name={@form[:chain_ring].name}
              label={gettext("Chain ring")}
              value={@chain_ring}
              min={Calculations.chain_ring_min()}
              max={Calculations.chain_ring_max()}
            />
            <.gear_slider
              id="rear-sprocket-slider"
              input_id="rear-sprocket"
              name={@form[:rear_sprocket].name}
              label={gettext("Rear sprocket")}
              value={@rear_sprocket}
              min={Calculations.sprocket_min()}
              max={Calculations.sprocket_max()}
            />
            <.input
              field={@form[:tire_width]}
              type="select"
              label={gettext("Tire")}
              options={Bikes.tire_options()}
            />
          </div>

          <.cadence_slider
            cadence={@cadence}
            name={@form[:cadence].name}
          />
        </.form>

        <div
          id="skid-patch-readout"
          class="rounded-3xl border border-base-300 bg-base-100 p-4 shadow-sm sm:p-5"
        >
          <.gear_readout
            id_prefix="playground"
            chain_ring={@chain_ring}
            rear_sprocket={@rear_sprocket}
            tire_width={@tire_width}
            cadence={@cadence}
          />
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Skid Patch"))
     |> assign_playground(%{})}
  end

  @impl true
  def handle_event("update", %{"skid_patch" => params}, socket) do
    {:noreply, assign_playground(socket, params)}
  end

  defp assign_playground(socket, params) do
    socket
    |> assign(
      :chain_ring,
      parse_option(params["chain_ring"], ring_values(), @default_ring)
    )
    |> assign(
      :rear_sprocket,
      parse_option(params["rear_sprocket"], cog_values(), @default_cog)
    )
    |> assign(
      :tire_width,
      parse_option(params["tire_width"], tire_values(), @default_tire)
    )
    |> assign(:cadence, CadenceColor.parse(params["cadence"]))
    |> assign_form()
  end

  defp assign_form(socket) do
    assign(
      socket,
      :form,
      to_form(
        %{
          "chain_ring" => socket.assigns.chain_ring,
          "rear_sprocket" => socket.assigns.rear_sprocket,
          "tire_width" => socket.assigns.tire_width,
          "cadence" => socket.assigns.cadence
        },
        as: :skid_patch
      )
    )
  end

  defp parse_option(value, allowed, default) do
    case Integer.parse(to_string(value || "")) do
      {parsed, _} -> if parsed in allowed, do: parsed, else: default
      :error -> default
    end
  end

  defp ring_values,
    do: Calculations.chain_ring_min()..Calculations.chain_ring_max()

  defp cog_values, do: Calculations.sprocket_min()..Calculations.sprocket_max()

  defp tire_values, do: Calculations.tire_widths()
end
