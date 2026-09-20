defmodule FixedGearWeb.RankingLive do
  use FixedGearWeb, :live_view

  alias FixedGear.Bikes
  alias FixedGear.Bikes.Bike
  alias FixedGear.Bikes.Calculations
  alias FixedGearWeb.ExpandableList

  @default_cadence 90

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-8">
        <header class="flex flex-col gap-6">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div class="space-y-2">
              <p class="text-xs font-semibold tracking-[0.25em] text-base-content/50 uppercase">
                Weigh-in
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
              class="flex w-fit rounded-full border border-base-300 bg-base-200 p-1"
            >
              <button
                id="tab-weight"
                type="button"
                phx-click="set_tab"
                phx-value-tab="weight"
                class={tab_class(@tab == :weight)}
              >
                Weight
              </button>
              <button
                id="tab-cadence"
                type="button"
                phx-click="set_tab"
                phx-value-tab="cadence"
                class={tab_class(@tab == :cadence)}
              >
                Cadence
              </button>
            </div>
          </div>

          <form
            :if={@tab == :cadence}
            id="cadence-form"
            phx-change="set_cadence"
            class="w-full max-w-xs self-end"
          >
            <label
              for="cadence"
              class="flex items-baseline justify-between text-sm"
            >
              <span class="text-base-content/60">Cadence</span>
              <span id="cadence-value" class="font-mono tabular-nums">
                {@cadence} rpm
              </span>
            </label>
            <input
              id="cadence"
              type="range"
              name="cadence"
              min="60"
              max="120"
              value={@cadence}
              class="range range-sm mt-2 w-full"
            />
          </form>
        </header>

        <div
          id="ranking"
          class="divide-y divide-base-300 overflow-hidden rounded-3xl border border-base-300 bg-base-100 shadow-sm"
        >
          <div
            id="ranking-empty"
            class="hidden px-5 py-16 text-center text-sm text-base-content/55 only:block"
          >
            No bikes weighed yet.
          </div>

          <.expandable_list_row
            :for={{bike, rank} <- @ranked_bikes}
            id={"bike-#{bike.id}"}
            toggle_key={bike.id}
            expanded={ExpandableList.expanded?(@expanded, to_string(bike.id))}
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
              <.link
                :if={@current_scope && @current_scope.user}
                id={"edit-bike-#{bike.id}"}
                navigate={~p"/admin/bikes/#{bike}/edit"}
                class="inline-flex rounded-full p-2 text-base-content/50 transition hover:bg-base-200 hover:text-base-content"
                aria-label={"Edit #{bike.name}"}
              >
                <.icon name="hero-pencil-square" class="size-5" />
              </.link>
            </:actions>
            <:content>
              <.bike_details bike={bike} cadence={@cadence} />
            </:content>
          </.expandable_list_row>
        </div>
      </section>
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
    ratio =
      Calculations.gear_ratio(
        assigns.bike.chain_ring,
        assigns.bike.rear_sprocket
      )

    patches =
      Calculations.skid_patches(
        assigns.bike.chain_ring,
        assigns.bike.rear_sprocket
      )

    speed = bike_speed(assigns.bike, assigns.cadence)

    assigns =
      assigns
      |> assign(:ratio, ratio)
      |> assign(:patches, patches)
      |> assign(:speed, speed)

    ~H"""
    <div class="grid gap-6 sm:grid-cols-[minmax(0,14rem)_1fr]">
      <div
        :if={Bike.photo?(@bike)}
        class="overflow-hidden rounded-xl bg-base-300"
      >
        <img
          src={~p"/bikes/#{@bike}/photo"}
          alt={"Photo of #{@bike.name}"}
          class="aspect-[4/3] h-full w-full object-cover"
        />
      </div>
      <div
        :if={not Bike.photo?(@bike)}
        class="flex aspect-[4/3] items-center justify-center rounded-xl border border-dashed border-base-300 text-xs text-base-content/45"
      >
        No photo
      </div>

      <div class="space-y-5">
        <dl class="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
          <.stat :if={@bike.frame_material} label="Frame">
            {frame_copy(@bike)}
          </.stat>
          <.stat :if={@bike.handlebar_material} label="Handlebar">
            {Calculations.material_label(@bike.handlebar_material)}
          </.stat>
          <.stat :if={@bike.chain_ring && @bike.rear_sprocket} label="Gearing">
            {@bike.chain_ring}t / {@bike.rear_sprocket}t
          </.stat>
          <.stat :if={@bike.tire_width} label="Tire">
            {Calculations.tire_label(@bike.tire_width)}
          </.stat>
          <.stat :if={@speed} label={"Speed at #{@cadence} rpm"}>
            {Calculations.format_speed(@speed)} km/h
          </.stat>
        </dl>

        <.stat :if={@ratio} label="Ratio">
          <.ratio_motion
            id={"ratio-motion-#{@bike.id}"}
            ratio={@ratio}
            label={Calculations.format_ratio(@ratio)}
          />
        </.stat>

        <.stat :if={@patches} label="Skid patches">
          <.skid_wheel
            id={"skid-wheel-#{@bike.id}"}
            patches={@patches.one_sided}
          />
          <p class="mt-1 text-xs text-base-content/55">
            {@patches.ambidextrous} both feet
          </p>
        </.stat>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp stat(assigns) do
    ~H"""
    <div>
      <dt class="text-xs tracking-wide text-base-content/50 uppercase">
        {@label}
      </dt>
      <dd class="mt-0.5 font-medium">{render_slot(@inner_block)}</dd>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Ranking")
     |> assign(:tab, :weight)
     |> assign(:cadence, @default_cadence)
     |> assign(:expanded, ExpandableList.new())
     |> assign(:bikes, Bikes.list_bikes())
     |> assign_ranking()}
  end

  @impl true
  def handle_event("toggle_expand", %{"key" => key}, socket) do
    expanded = ExpandableList.toggle(socket.assigns.expanded, key)
    {:noreply, assign(socket, :expanded, expanded)}
  end

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply,
     socket
     |> assign(:tab, tab_from_param(tab))
     |> assign_ranking()}
  end

  def handle_event("set_cadence", %{"cadence" => cadence}, socket) do
    rpm =
      case Integer.parse(cadence) do
        {value, _} -> value |> max(60) |> min(120)
        :error -> @default_cadence
      end

    {:noreply,
     socket
     |> assign(:cadence, rpm)
     |> assign_ranking()}
  end

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

  defp tab_from_param("cadence"), do: :cadence
  defp tab_from_param(_), do: :weight

  defp page_heading(:weight, _cadence), do: "Lightest first"

  defp page_heading(:cadence, cadence),
    do: "Fastest at #{cadence} rpm"

  defp page_blurb(:weight),
    do: "Ranked by scale weight. Open a bike for gearing and details."

  defp page_blurb(:cadence),
    do: "Who covers more ground at this cadence. Missing gearing sits last."

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
    material = Calculations.material_label(bike.frame_material)

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
