defmodule FixedGearWeb.RankingComponents do
  @moduledoc false

  use Phoenix.Component
  use Gettext, backend: FixedGearWeb.Gettext

  import FixedGearWeb.CoreComponents, only: [icon: 1]

  alias FixedGear.Bikes.Calculations
  alias FixedGearWeb.CadenceColor
  alias Phoenix.LiveView.JS

  @max_skid_ticks 24
  @spoke_count 32
  @spoke_angles Enum.map(0..(@spoke_count - 1), fn i ->
                  i * 360.0 / @spoke_count
                end)
  @reference_rpm 90
  @seconds_per_minute 60

  attr :id, :string, required: true
  attr :expanded, :boolean, required: true
  attr :toggle_href, :string, required: true
  attr :content_class, :string, default: nil

  slot :leading
  slot :title, required: true
  slot :subtitle
  slot :meta
  slot :actions
  slot :content, required: true

  def expandable_list_row(assigns) do
    ~H"""
    <div id={@id} class="flex min-w-0 flex-col px-4 py-4 sm:px-5">
      <div class="flex w-full min-w-0 items-center gap-2">
        <.link
          id={"#{@id}-header"}
          patch={@toggle_href}
          phx-keydown={JS.dispatch("click")}
          phx-key="Enter"
          onkeydown="if (event.key === ' ') { event.preventDefault(); event.currentTarget.click() }"
          aria-expanded={@expanded}
          aria-controls={"#{@id}-expand"}
          class="flex min-w-0 flex-1 cursor-pointer items-center gap-4"
        >
          <div :if={@leading != []} class="shrink-0">
            {render_slot(@leading)}
          </div>

          <div class="min-w-0 flex-1 overflow-hidden">
            <div class="truncate text-base font-medium tracking-tight">
              {render_slot(@title)}
            </div>
            <div
              :if={@subtitle != []}
              class="mt-0.5 truncate text-sm text-base-content/60"
            >
              {render_slot(@subtitle)}
            </div>
          </div>

          <div :if={@meta != []} class="shrink-0 text-right">
            {render_slot(@meta)}
          </div>

          <span
            class="inline-flex shrink-0 text-base-content/40"
            aria-hidden="true"
          >
            <.icon
              name={
                if @expanded,
                  do: "hero-chevron-up-solid",
                  else: "hero-chevron-down-solid"
              }
              class="size-4"
            />
          </span>
          <span class="sr-only">
            {if @expanded, do: gettext("Collapse"), else: gettext("Expand")}
          </span>
        </.link>

        <div :if={@actions != []} class="shrink-0">
          {render_slot(@actions)}
        </div>
      </div>

      <div
        id={"#{@id}-expand"}
        role="region"
        aria-hidden={if @expanded, do: "false", else: "true"}
        class={[
          "grid overflow-hidden transition-all duration-300 ease-in-out",
          if(@expanded,
            do: "grid-rows-[1fr] opacity-100",
            else: "grid-rows-[0fr] opacity-0"
          )
        ]}
      >
        <%= if @expanded do %>
          <div
            id={"#{@id}-expand-inner"}
            class="min-h-0 overflow-hidden"
            phx-remove={keep_panel_during_collapse()}
          >
            <div class={[
              "mt-4 rounded-2xl border border-base-300 bg-base-200/60 p-4",
              @content_class
            ]}>
              {render_slot(@content)}
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @bike_photo_frame_class "aspect-[3/2] w-full self-start overflow-hidden rounded-xl bg-base-300"
  @bike_photo_img_class "h-full w-full object-contain"

  attr :id, :string, default: nil
  attr :src, :string, required: true
  attr :alt, :string, required: true

  def bike_photo(assigns) do
    assigns =
      assigns
      |> assign(:frame_class, @bike_photo_frame_class)
      |> assign(:img_class, @bike_photo_img_class)

    ~H"""
    <div id={@id} class={@frame_class}>
      <img src={@src} alt={@alt} class={@img_class} />
    </div>
    """
  end

  def bike_photo_frame_class, do: @bike_photo_frame_class

  def bike_photo_img_class, do: @bike_photo_img_class

  attr :id, :string, default: nil
  slot :inner_block, required: true

  def bike_photo_placeholder(assigns) do
    ~H"""
    <div
      id={@id}
      class="flex aspect-[3/2] w-full self-start items-center justify-center rounded-xl border border-dashed border-base-300 text-xs text-base-content/45"
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :id, :string, required: true
  attr :patches, :integer, required: true
  attr :ambidextrous, :integer, default: nil

  def skid_wheel(assigns) do
    count =
      if assigns.patches in 1..@max_skid_ticks do
        assigns.patches
      else
        0
      end

    step = if count > 0, do: 360 / count, else: 0
    show_ambi? = ambi_extra?(assigns.ambidextrous, count)
    blob_n = if show_ambi?, do: count * 2, else: count
    blob_rx = skid_blob_rx(blob_n)
    blob_ry = blob_rx * 0.78

    marks =
      if count > 0 do
        Enum.flat_map(0..(count - 1), fn i ->
          one = %{
            ambi: false,
            angle: -i * step,
            rx: blob_rx,
            ry: blob_ry
          }

          if show_ambi? do
            [
              one,
              %{
                ambi: true,
                angle: -i * step - step / 2,
                rx: blob_rx,
                ry: blob_ry
              }
            ]
          else
            [one]
          end
        end)
      else
        []
      end

    displayed = if show_ambi?, do: assigns.ambidextrous, else: assigns.patches

    assigns =
      assigns
      |> assign(:marks, marks)
      |> assign(:show_ambi, show_ambi?)
      |> assign(:displayed, displayed)
      |> assign(:spokes, @spoke_angles)

    ~H"""
    <div
      id={@id}
      phx-hook="SkidWheel"
      data-patches={@patches}
      data-ambidextrous={@ambidextrous}
    >
      <div class="flex items-center gap-4">
        <div
          id={"#{@id}-stage-#{@patches}-#{@displayed}"}
          phx-update="ignore"
          class="relative size-16 shrink-0 sm:size-20"
        >
          <svg
            viewBox="0 0 80 80"
            class="skid-wheel-rotor size-full text-base-content"
            aria-hidden="true"
          >
            <circle
              cx="40"
              cy="40"
              r="28"
              fill="none"
              stroke="currentColor"
              stroke-width="8"
              class="opacity-35"
            />
            <g :for={angle <- @spokes} transform={"rotate(#{angle} 40 40)"}>
              <line
                x1="40"
                y1="33.2"
                x2="40"
                y2="16.5"
                stroke="currentColor"
                stroke-width="0.7"
                class="opacity-35"
              />
            </g>
            <circle cx="40" cy="40" r="5.5" fill="currentColor" class="opacity-40" />
            <g
              :for={{mark, index} <- Enum.with_index(@marks)}
              id={"#{@id}-mark-#{index}"}
              class={["skid-patch", mark.ambi && "skid-patch-ambi"]}
              transform={"rotate(#{mark.angle} 40 40)"}
            >
              <ellipse cx="40" cy="12" rx={mark.rx} ry={mark.ry} />
              <ellipse
                cx="41.8"
                cy="10.8"
                rx={mark.rx * 0.62}
                ry={mark.ry * 0.58}
              />
            </g>
          </svg>
          <span class="skid-wheel-ground" aria-hidden="true"></span>
          <span class="skid-sparks" aria-hidden="true"></span>
        </div>
        <p
          id={"#{@id}-count"}
          class="font-mono text-lg leading-none font-semibold tabular-nums"
        >
          {@displayed}
        </p>
        <p
          :if={@show_ambi}
          class="min-w-0 flex-1 text-[11px] leading-snug text-base-content/55"
        >
          <span class="skid-legend-ambi">{gettext("both pedals")}</span>
          <span class="skid-legend-one mt-1 block">
            {gettext("%{count} one foot", count: @patches)}
          </span>
        </p>
      </div>
    </div>
    """
  end

  attr :tab, :atom, required: true
  attr :cadence, :integer, required: true

  def cadence_dock(assigns) do
    ~H"""
    <form
      id="cadence-form"
      phx-change="set_cadence"
      aria-hidden={to_string(@tab != :cadence)}
      inert={@tab != :cadence}
      class={[
        "cadence-dock absolute inset-x-0 bottom-full z-0 px-4 pb-2 sm:px-6 lg:px-8",
        "transition-transform duration-300 ease-out motion-reduce:transition-none",
        @tab == :cadence && "translate-y-0",
        @tab != :cadence &&
          "pointer-events-none translate-y-[calc(100%+1.5rem)]"
      ]}
    >
      <div
        id="cadence-dock"
        class="mx-auto max-w-4xl rounded-3xl border border-base-300 bg-base-100/95 p-4 shadow-lg backdrop-blur"
      >
        <div
          class="mx-auto mb-3 h-1 w-10 rounded-full bg-base-content/15"
          aria-hidden="true"
        />
        <.cadence_slider cadence={@cadence} />
      </div>
    </form>
    """
  end

  attr :id, :string, default: "cadence-slider"
  attr :cadence, :integer, required: true
  attr :name, :string, default: "cadence"
  attr :input_id, :string, default: "cadence"

  def cadence_slider(assigns) do
    assigns =
      assigns
      |> assign(:color, CadenceColor.css(assigns.cadence))
      |> assign(:progress, CadenceColor.progress_percent(assigns.cadence))

    ~H"""
    <div
      id={@id}
      class="cadence-slider w-full"
      phx-hook="CadenceSlider"
      style={"--cadence-color: #{@color}; --cadence-progress: #{@progress}%"}
      data-cadence-color={@color}
      data-cadence-progress={"#{@progress}%"}
    >
      <label
        for={@input_id}
        class="flex items-baseline justify-between text-sm"
      >
        <span class="text-base-content/60">{gettext("Cadence")}</span>
        <span
          id="cadence-value"
          data-cadence-value
          class="font-mono tabular-nums"
          style={"color: #{@color}"}
        >
          {@cadence} rpm
        </span>
      </label>
      <input
        id={@input_id}
        type="range"
        name={@name}
        min={CadenceColor.min_rpm()}
        max={CadenceColor.max_rpm()}
        value={@cadence}
        class="cadence-slider-input mt-2 w-full"
      />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :input_id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :min, :integer, required: true
  attr :max, :integer, required: true
  attr :suffix, :string, default: "t"

  def gear_slider(assigns) do
    ~H"""
    <div
      id={@id}
      class="plain-slider w-full"
      phx-hook="SliderValue"
      data-suffix={@suffix}
    >
      <label
        for={@input_id}
        class="flex items-baseline justify-between text-sm"
      >
        <span class="text-base-content/60">{@label}</span>
        <span
          id={"#{@input_id}-value"}
          data-slider-value
          class="font-mono tabular-nums"
        >
          {@value}{@suffix}
        </span>
      </label>
      <input
        id={@input_id}
        type="range"
        name={@name}
        min={@min}
        max={@max}
        step="1"
        value={@value}
        class="plain-slider-input mt-2 w-full"
      />
    </div>
    """
  end

  attr :id_prefix, :string, required: true
  attr :chain_ring, :integer, default: nil
  attr :rear_sprocket, :integer, default: nil
  attr :tire_width, :integer, default: nil
  attr :cadence, :integer, required: true

  def gear_readout(assigns) do
    ratio = Calculations.gear_ratio(assigns.chain_ring, assigns.rear_sprocket)

    patches =
      Calculations.skid_patches(assigns.chain_ring, assigns.rear_sprocket)

    speed =
      Calculations.speed_kmh(
        assigns.chain_ring,
        assigns.rear_sprocket,
        assigns.tire_width,
        assigns.cadence
      )

    assigns =
      assigns
      |> assign(:ratio, ratio)
      |> assign(:patches, patches)
      |> assign(:speed, speed)

    ~H"""
    <div class="space-y-5">
      <dl class="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
        <.stat
          :if={@chain_ring && @rear_sprocket}
          label={gettext("Gearing")}
        >
          {@chain_ring}t / {@rear_sprocket}t
        </.stat>
        <.stat :if={@tire_width} label={gettext("Tire")}>
          {Calculations.tire_label(@tire_width)}
        </.stat>
        <.stat
          :if={@speed}
          label={gettext("Speed at %{cadence} rpm", cadence: @cadence)}
        >
          {Calculations.format_speed(@speed)} km/h
        </.stat>
      </dl>

      <.stat :if={@ratio} label={gettext("Ratio")}>
        <.ratio_motion
          id={"ratio-motion-#{@id_prefix}"}
          ratio={@ratio}
          cadence={@cadence}
          label={Calculations.format_ratio(@ratio)}
        />
      </.stat>

      <.stat :if={@patches} label={gettext("Skid patches")}>
        <.skid_wheel
          id={"skid-wheel-#{@id_prefix}"}
          patches={@patches.one_sided}
          ambidextrous={@patches.ambidextrous}
        />
        <.skid_patch_credit />
      </.stat>
    </div>
    """
  end

  def skid_patch_credit(assigns) do
    ~H"""
    <p class="skid-patch-credit mt-2 text-[10px] leading-snug text-base-content/40">
      {gettext("Inspired by")}
      <a
        href="https://www.surplace.fr/ffgc/"
        target="_blank"
        rel="noopener noreferrer"
        class="underline decoration-base-content/25 underline-offset-2 transition hover:text-base-content/70 hover:decoration-base-content/50"
      >
        surplace.fr/ffgc
      </a>
    </p>
    """
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  def stat(assigns) do
    ~H"""
    <div>
      <dt class="text-xs tracking-wide text-base-content/50 uppercase">
        {@label}
      </dt>
      <dd class="mt-0.5 font-medium">{render_slot(@inner_block)}</dd>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :ratio, :float, required: true
  attr :label, :string, required: true
  attr :cadence, :integer, required: true

  def ratio_motion(assigns) do
    pedal_seconds = visual_pedal_seconds(@reference_rpm)
    wheel_seconds = pedal_seconds / assigns.ratio

    assigns =
      assigns
      |> assign(:pedal_ms, round(pedal_seconds * 1000))
      |> assign(:wheel_ms, round(wheel_seconds * 1000))

    ~H"""
    <div
      id={@id}
      class="flex items-center gap-4"
      phx-hook="RatioMotion"
      data-cadence={@cadence}
      data-pedal-ms={@pedal_ms}
      data-wheel-ms={@wheel_ms}
    >
      <div class="flex items-end gap-3">
        <div class="flex w-14 flex-col items-center gap-1 sm:w-16">
          <div class="flex h-14 w-14 items-center justify-center sm:h-16 sm:w-16">
            <svg
              viewBox="0 0 64 64"
              data-spin="wheel"
              class="ratio-spin size-14 origin-center motion-reduce:animate-none sm:size-16"
              aria-hidden="true"
            >
              <circle
                cx="32"
                cy="32"
                r="24"
                fill="none"
                stroke="currentColor"
                stroke-width="5"
              />
              <circle cx="32" cy="32" r="4" fill="currentColor" />
              <line
                x1="32"
                y1="32"
                x2="32"
                y2="10"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
              />
            </svg>
          </div>
          <span class="text-[11px] leading-none tracking-wide text-base-content/55 uppercase">
            {gettext("Wheel")}
          </span>
        </div>

        <div class="flex w-14 flex-col items-center gap-1 sm:w-16">
          <div class="flex h-14 w-14 items-center justify-center sm:h-16 sm:w-16">
            <svg
              viewBox="0 0 64 64"
              data-spin="pedal"
              class="ratio-spin size-11 origin-center motion-reduce:animate-none sm:size-12"
              aria-hidden="true"
            >
              <circle
                cx="32"
                cy="32"
                r="20"
                fill="none"
                stroke="currentColor"
                stroke-width="3"
              />
              <line
                x1="32"
                y1="32"
                x2="32"
                y2="14"
                stroke="currentColor"
                stroke-width="3"
                stroke-linecap="round"
              />
              <circle cx="32" cy="14" r="4" fill="currentColor" />
            </svg>
          </div>
          <span class="text-[11px] leading-none tracking-wide text-base-content/55 uppercase">
            {gettext("Pedal")}
          </span>
        </div>
      </div>
      <div class="flex min-w-0 flex-wrap items-baseline gap-x-2 gap-y-0.5">
        <p class="font-mono text-lg leading-none font-semibold tabular-nums">
          {@label}
        </p>
        <p class="text-[11px] leading-snug text-base-content/55">
          {gettext("wheel turns per pedal stroke")}
        </p>
      </div>
    </div>
    """
  end

  defp skid_blob_rx(n) when n > 12, do: 3.8
  defp skid_blob_rx(n) when n > 6, do: 4.7
  defp skid_blob_rx(_n), do: 5.6

  defp ambi_extra?(ambi, one_sided)
       when is_integer(ambi) and is_integer(one_sided) and ambi > one_sided,
       do: true

  defp ambi_extra?(_ambi, _one_sided), do: false

  defp visual_pedal_seconds(rpm) when is_integer(rpm) and rpm > 0 do
    @seconds_per_minute / rpm
  end

  defp visual_pedal_seconds(_rpm), do: @seconds_per_minute / @reference_rpm

  defp keep_panel_during_collapse do
    JS.hide(
      time: 300,
      transition:
        {"transition-all duration-300 ease-in-out", "opacity-100",
         "opacity-100"}
    )
  end
end
