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
      <section class="space-y-6 pb-36">
        <header class="flex items-start justify-between gap-4">
          <div class="min-w-0 space-y-2">
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
          </div>
          <div class="shrink-0 pt-6">
            <button
              id="share-skid-patch"
              type="button"
              phx-hook="ShareLink"
              phx-update="ignore"
              data-url={
                playground_path(@chain_ring, @rear_sprocket, @tire_width, @cadence)
              }
              data-title={share_title(@chain_ring, @rear_sprocket)}
              data-copied-label={gettext("Link copied")}
              class="inline-flex rounded-full p-2 text-base-content/50 transition hover:bg-base-200 hover:text-base-content"
              aria-label={gettext("Share this setup")}
            >
              <span data-share-icon class="inline-flex">
                <.icon name="hero-arrow-up-on-square" class="size-5" />
              </span>
              <span data-copied-icon class="hidden">
                <.icon name="hero-check" class="size-5" />
              </span>
              <span
                id="share-skid-patch-status"
                class="sr-only"
                aria-live="polite"
              ></span>
            </button>
          </div>
        </header>

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

      <:bottom_dock>
        <.form
          for={@form}
          id="skid-patch-form"
          phx-change="update"
          class="absolute inset-x-0 bottom-full z-0 px-4 pb-2 sm:px-6 lg:px-8"
        >
          <div
            id="skid-patch-controls"
            class="mx-auto max-w-4xl rounded-3xl border border-base-300 bg-base-100/95 p-4 shadow-lg backdrop-blur"
          >
            <div
              class="mx-auto mb-3 h-1 w-10 rounded-full bg-base-content/15"
              aria-hidden="true"
            />
            <div class="space-y-3">
              <div class="grid grid-cols-2 gap-x-4 gap-y-3">
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
              </div>
              <.input
                field={@form[:tire_width]}
                type="select"
                label={gettext("Tire")}
                options={Bikes.tire_options()}
                class="w-full select select-sm"
              />
              <.cadence_slider
                cadence={@cadence}
                name={@form[:cadence].name}
              />
            </div>
          </div>
        </.form>
      </:bottom_dock>
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
  def handle_params(params, _uri, socket) do
    socket = assign_playground(socket, params)

    socket =
      if canonical_query?(params, socket) do
        socket
      else
        push_patch(socket, to: current_playground_path(socket), replace: true)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update", %{"skid_patch" => params}, socket) do
    socket = assign_playground(socket, params)

    {:noreply,
     push_patch(socket, to: current_playground_path(socket), replace: true)}
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
    |> assign(:cadence, parse_cadence(params["cadence"]))
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
      {parsed, ""} -> if parsed in allowed, do: parsed, else: default
      _ -> default
    end
  end

  defp parse_cadence(value) do
    parse_option(
      value,
      CadenceColor.min_rpm()..CadenceColor.max_rpm(),
      CadenceColor.default_rpm()
    )
  end

  defp ring_values,
    do: Calculations.chain_ring_min()..Calculations.chain_ring_max()

  defp cog_values, do: Calculations.sprocket_min()..Calculations.sprocket_max()

  defp tire_values, do: Calculations.tire_widths()

  defp current_playground_path(socket) do
    playground_path(
      socket.assigns.chain_ring,
      socket.assigns.rear_sprocket,
      socket.assigns.tire_width,
      socket.assigns.cadence
    )
  end

  defp playground_path(chain_ring, rear_sprocket, tire_width, cadence) do
    query =
      []
      |> maybe_param(:chain_ring, chain_ring, @default_ring)
      |> maybe_param(:rear_sprocket, rear_sprocket, @default_cog)
      |> maybe_param(:tire_width, tire_width, @default_tire)
      |> maybe_param(:cadence, cadence, CadenceColor.default_rpm())

    case query do
      [] -> ~p"/skid-patch"
      query -> ~p"/skid-patch?#{query}"
    end
  end

  defp maybe_param(query, _key, value, default) when value == default, do: query
  defp maybe_param(query, key, value, _default), do: query ++ [{key, value}]

  defp canonical_query?(params, socket) do
    query_value(params, "chain_ring") ==
      canonical_value(socket.assigns.chain_ring, @default_ring) and
      query_value(params, "rear_sprocket") ==
        canonical_value(socket.assigns.rear_sprocket, @default_cog) and
      query_value(params, "tire_width") ==
        canonical_value(socket.assigns.tire_width, @default_tire) and
      query_value(params, "cadence") ==
        canonical_value(socket.assigns.cadence, CadenceColor.default_rpm())
  end

  defp canonical_value(value, default) when value == default, do: nil
  defp canonical_value(value, _default), do: to_string(value)

  defp query_value(params, key) do
    case params[key] do
      nil -> nil
      value -> to_string(value)
    end
  end

  defp share_title(chain_ring, rear_sprocket) do
    gettext("Skid Patch") <>
      " · " <>
      Bikes.tooth_label(chain_ring) <>
      " / " <>
      Bikes.tooth_label(rear_sprocket)
  end
end
