defmodule FixedGearWeb.RankingLive do
  use FixedGearWeb, :live_view

  alias FixedGear.Bikes
  alias FixedGear.Bikes.Bike
  alias FixedGear.Bikes.Calculations
  alias FixedGearWeb.CadenceColor
  alias FixedGearWeb.TimeAgo

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} section={:ranking}>
      <section class={["space-y-6", @tab == :cadence && "pb-28"]}>
        <header
          id="ranking-toolbar"
          class="sticky top-(--app-header-height) z-20 -mx-4 flex flex-col gap-4 bg-base-100/95 px-4 py-4 backdrop-blur sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8"
        >
          <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div class="space-y-2">
              <p
                id="ranking-kicker"
                class="text-xs font-semibold tracking-[0.25em] text-base-content/50 uppercase"
              >
                {page_kicker(@tab)}
              </p>
              <h1 class="text-3xl font-semibold tracking-tight sm:text-4xl">
                {page_heading(@tab, @cadence)}
              </h1>
              <p class="max-w-md text-sm text-base-content/65">
                {page_blurb(@tab)}
              </p>
            </div>

            <div
              id="ranking-tabs"
              role="tablist"
              aria-label={gettext("Ranking")}
              class="flex w-fit rounded-full border border-base-300 bg-base-200 p-1"
            >
              <.link
                id="tab-weight"
                patch={ranking_href(:weight, @expanded_id)}
                replace
                role="tab"
                aria-selected={to_string(@tab == :weight)}
                aria-controls="ranking"
                class={tab_class(@tab == :weight)}
              >
                {gettext("Weight")}
              </.link>
              <.link
                id="tab-cadence"
                patch={ranking_href(:cadence, @expanded_id)}
                replace
                role="tab"
                aria-selected={to_string(@tab == :cadence)}
                aria-controls="ranking"
                class={tab_class(@tab == :cadence)}
              >
                {gettext("Cadence")}
              </.link>
            </div>
          </div>
        </header>

        <div
          id="ranking"
          role="tabpanel"
          aria-labelledby={
            if(@tab == :weight, do: "tab-weight", else: "tab-cadence")
          }
          phx-hook="RankingList"
          class="divide-y divide-base-300 overflow-hidden rounded-3xl border border-base-300 bg-base-100 shadow-sm"
        >
          <div
            id="ranking-empty"
            class="hidden px-5 py-16 text-center text-sm text-base-content/55 only:block"
          >
            {gettext("No bikes weighed yet.")}
          </div>

          <.expandable_list_row
            :for={{bike, rank} <- @ranked_bikes}
            id={"bike-#{bike.id}"}
            toggle_href={row_href(@tab, @expanded_id, bike.id)}
            expanded={@expanded_id == bike.id}
          >
            <:leading>
              <span class={[
                "flex size-10 items-center justify-center rounded-full font-mono text-sm tabular-nums",
                rank_class(rank)
              ]}>
                {rank}
              </span>
            </:leading>
            <:title>{bike.name}</:title>
            <:subtitle>{bike.owner}</:subtitle>
            <:meta>
              <.row_meta tab={@tab} bike={bike} cadence={@cadence} />
            </:meta>
            <:actions>
              <div class="flex items-center">
                <button
                  id={"share-bike-#{bike.id}"}
                  type="button"
                  phx-hook="ShareLink"
                  data-url={ranking_href(@tab, bike.id)}
                  data-title={bike.name}
                  data-copied-label={gettext("Link copied")}
                  class="inline-flex rounded-full p-2 text-base-content/50 transition hover:bg-base-200 hover:text-base-content"
                  aria-label={gettext("Share %{name}", name: bike.name)}
                >
                  <span data-share-icon class="inline-flex">
                    <.icon name="hero-arrow-up-on-square" class="size-5" />
                  </span>
                  <span data-copied-icon class="hidden">
                    <.icon name="hero-check" class="size-5" />
                  </span>
                </button>
                <span
                  id={"share-bike-#{bike.id}-status"}
                  class="sr-only"
                  aria-live="polite"
                ></span>
                <.link
                  :if={
                    @current_scope && @current_scope.user &&
                      @current_scope.user.admin
                  }
                  id={"edit-bike-#{bike.id}"}
                  navigate={~p"/admin/bikes/#{bike}/edit"}
                  class="inline-flex rounded-full p-2 text-base-content/50 transition hover:bg-base-200 hover:text-base-content"
                  aria-label={gettext("Edit %{name}", name: bike.name)}
                >
                  <.icon name="hero-pencil-square" class="size-5" />
                </.link>
              </div>
            </:actions>
            <:content>
              <.bike_details bike={bike} cadence={@cadence} />
            </:content>
          </.expandable_list_row>
        </div>
      </section>

      <:bottom_dock>
        <.cadence_dock tab={@tab} cadence={@cadence} form={@cadence_form} />
      </:bottom_dock>
    </Layouts.app>
    """
  end

  defp row_meta(%{tab: :weight} = assigns) do
    ~H"""
    <p class="font-mono text-xl font-semibold tabular-nums tracking-tight sm:text-2xl">
      {Calculations.format_weight(@bike.weight_kg)}
      <span class="text-sm font-normal text-base-content/50">kg</span>
    </p>
    """
  end

  defp row_meta(assigns) do
    speed = bike_speed(assigns.bike, assigns.cadence)
    assigns = assign(assigns, :speed, speed)

    ~H"""
    <p class="font-mono text-xl font-semibold tabular-nums tracking-tight sm:text-2xl">
      <%= if @speed do %>
        {Calculations.format_speed(@speed)}
        <span class="text-sm font-normal text-base-content/50">km/h</span>
      <% else %>
        <span class="text-base-content/40">—</span>
      <% end %>
    </p>
    """
  end

  defp bike_details(assigns) do
    ~H"""
    <div class="grid gap-6 lg:grid-cols-[minmax(0,28rem)_1fr]">
      <.bike_photo
        :if={Bike.photo?(@bike)}
        id={"bike-#{@bike.id}-photo"}
        src={~p"/bikes/#{@bike}/photo?#{[v: DateTime.to_unix(@bike.updated_at)]}"}
        alt={gettext("Photo of %{name}", name: @bike.name)}
      />
      <.bike_photo_placeholder :if={not Bike.photo?(@bike)}>
        {gettext("No photo")}
      </.bike_photo_placeholder>

      <div class="space-y-5">
        <dl class="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
          <.stat :if={@bike.frame_material} label={gettext("Frame")}>
            {frame_copy(@bike)}
          </.stat>
          <.stat :if={@bike.handlebar_material} label={gettext("Handlebar")}>
            {translate_material(@bike.handlebar_material)}
          </.stat>
          <.stat label={gettext("Updated")}>
            <time
              id={"bike-#{@bike.id}-updated"}
              datetime={DateTime.to_iso8601(@bike.updated_at)}
            >
              {TimeAgo.format(@bike.updated_at)}
            </time>
          </.stat>
        </dl>

        <.gear_readout
          id_prefix={to_string(@bike.id)}
          chain_ring={@bike.chain_ring}
          rear_sprocket={@bike.rear_sprocket}
          tire_width={@bike.tire_width}
          cadence={@cadence}
        />
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Ranking"))
     |> assign(:tab, :weight)
     |> assign(:cadence, CadenceColor.default_rpm())
     |> assign(:expanded_id, nil)
     |> assign(:bikes, Bikes.list_bikes())
     |> assign(:ranked_bikes, [])
     |> assign_cadence_form()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case accepted_tab(params["tab"]) do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/ranking/weight")}

      tab ->
        case expanded_id_from_params(params, socket.assigns.bikes) do
          {:ok, expanded_id} ->
            {:noreply, apply_ranking_params(socket, tab, expanded_id)}

          :error ->
            {:noreply, push_navigate(socket, to: ranking_href(tab, nil))}
        end
    end
  end

  @impl true
  def handle_event("set_cadence", %{"cadence" => cadence}, socket) do
    {:noreply,
     socket
     |> assign(:cadence, CadenceColor.parse(cadence))
     |> assign_cadence_form()
     |> maybe_assign_ranking()}
  end

  defp apply_ranking_params(socket, tab, expanded_id) do
    previous_tab = socket.assigns.tab

    socket
    |> assign(:tab, tab)
    |> assign(:expanded_id, expanded_id)
    |> maybe_assign_ranking_for_params(previous_tab)
  end

  defp maybe_assign_ranking_for_params(socket, previous_tab) do
    if previous_tab == socket.assigns.tab and skip_zero_cadence_rerank?(socket) do
      socket
    else
      assign_ranking(socket)
    end
  end

  defp maybe_assign_ranking(
         %{assigns: %{tab: :cadence, cadence: cadence}} = socket
       )
       when cadence < 1,
       do: socket

  defp maybe_assign_ranking(socket), do: assign_ranking(socket)

  defp assign_cadence_form(socket) do
    assign(
      socket,
      :cadence_form,
      to_form(%{"cadence" => socket.assigns.cadence}, as: nil)
    )
  end

  defp skip_zero_cadence_rerank?(%{
         assigns: %{tab: :cadence, cadence: cadence, ranked_bikes: ranked}
       })
       when cadence < 1 and ranked != [],
       do: true

  defp skip_zero_cadence_rerank?(_socket), do: false

  defp assign_ranking(socket) do
    ranked =
      socket.assigns.bikes
      |> rank_bikes(socket.assigns.tab, socket.assigns.cadence)
      |> Enum.with_index(1)

    assign(socket, :ranked_bikes, ranked)
  end

  defp rank_bikes(bikes, :weight, _cadence) do
    Enum.sort_by(bikes, & &1.weight_kg, Decimal)
  end

  defp rank_bikes(bikes, :cadence, cadence) do
    Enum.sort_by(bikes, fn bike ->
      case bike_speed(bike, cadence) do
        nil -> {1, 0.0}
        speed -> {0, -speed}
      end
    end)
  end

  defp bike_speed(bike, cadence) do
    Calculations.speed_kmh(
      bike.chain_ring,
      bike.rear_sprocket,
      bike.tire_width,
      cadence
    )
  end

  defp accepted_tab("cadence"), do: :cadence
  defp accepted_tab("weight"), do: :weight
  defp accepted_tab(_tab), do: nil

  defp expanded_id_from_params(%{"id" => id}, bikes) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        if Enum.any?(bikes, &(&1.id == uuid)), do: {:ok, uuid}, else: :error

      :error ->
        :error
    end
  end

  defp expanded_id_from_params(_params, _bikes), do: {:ok, nil}

  defp row_href(tab, expanded_id, bike_id) do
    if expanded_id == bike_id do
      ranking_href(tab, nil)
    else
      ranking_href(tab, bike_id)
    end
  end

  defp ranking_href(tab, nil), do: ~p"/ranking/#{tab_param(tab)}"
  defp ranking_href(tab, id), do: ~p"/ranking/#{id}/#{tab_param(tab)}"

  defp tab_param(:cadence), do: "cadence"
  defp tab_param(_tab), do: "weight"

  defp page_kicker(:cadence), do: gettext("Cadence")
  defp page_kicker(_tab), do: gettext("Weigh-in")

  defp page_heading(:weight, _cadence), do: gettext("Lightest first")

  defp page_heading(:cadence, cadence),
    do: gettext("Fastest at %{cadence} rpm", cadence: cadence)

  defp page_blurb(:weight),
    do: gettext("Ranked by scale weight. Open a bike for gearing and details.")

  defp page_blurb(:cadence),
    do:
      gettext(
        "Setups from the heaviest to the lightest. Higher top speed at a lower cadence."
      )

  defp translate_material(:aluminum), do: gettext("Aluminum")
  defp translate_material(:steel), do: gettext("Steel")
  defp translate_material(:carbon_fiber), do: gettext("Carbon fiber")
  defp translate_material(_material), do: nil

  defp tab_class(true),
    do: "rounded-full bg-base-100 px-4 py-1.5 text-sm font-medium shadow-sm"

  defp tab_class(false),
    do:
      "rounded-full px-4 py-1.5 text-sm text-base-content/60 transition hover:text-base-content"

  defp rank_class(1), do: "bg-amber-400 text-amber-950"
  defp rank_class(2), do: "bg-zinc-300 text-zinc-800"
  defp rank_class(3), do: "bg-amber-800 text-amber-50"
  defp rank_class(_rank), do: "bg-base-200 text-base-content/70"

  defp frame_copy(bike) do
    material = translate_material(bike.frame_material)

    cond do
      bike.frame_name not in [nil, ""] and material ->
        "#{material} · #{bike.frame_name}"

      bike.frame_name not in [nil, ""] ->
        bike.frame_name

      true ->
        material
    end
  end
end
