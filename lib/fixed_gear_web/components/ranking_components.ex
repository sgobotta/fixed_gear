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
  @hub_holes Enum.map(0..4, fn i -> i * 72.0 end)
  @wheel_cx 40.0
  @wheel_cy 40.0
  @tire_outer 36.6
  @tire_inner 32.9
  @patch_outer 38.1
  @patch_inner 31.5
  @rim_r 31.8
  @spoke_inner 8.2
  @spoke_outer 31.3
  @hub_r 7.5
  @hub_axle_r 1.2
  @hub_petal_r 1.45
  @hub_petal_offset 2.7
  # Pitch radius = teeth * @pitch_unit, so both sprockets share one chain pitch.
  @tooth_addendum 2.2
  @tooth_dedendum 1.45
  @min_cog_pitch 5.4
  @tire_gap 2.2
  @pair_gap 3.4
  @vertical_pad 2.0
  @view_pad 2.2
  @bore_r 1.05
  @chain_stroke 1.45
  # Chain rides just outside the chainring teeth so the wrap reads on the
  # dark background. The cog wrap sits on the pitch circle, centered on the hub.
  @chain_clear 0.9
  # Cog center is the hub center, so the cog and chain cover the hub.
  # A 16t disc is the full size; larger cogs stay on this center and are
  # capped so the body does not grow past it.
  @cog_body_r 5.6
  @max_cog_pitch @cog_body_r + @tooth_dedendum
  @cog_cx @wheel_cx
  @pitch_unit @max_cog_pitch / 16
  # Tallest ring that fits the wheel's viewBox. Its center stays put so a
  # smaller ring does not slide, and the largest ring stays clear of the tire.
  @max_ring_pitch @wheel_cy - @vertical_pad - @tooth_addendum
  @ring_cx @wheel_cx + @tire_outer + @tire_gap + @max_ring_pitch +
             @tooth_addendum
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
  attr :chain_ring, :integer, required: true
  attr :rear_sprocket, :integer, required: true

  def skid_wheel(assigns) do
    count =
      if assigns.patches in 1..@max_skid_ticks do
        assigns.patches
      else
        0
      end

    step = if count > 0, do: 360 / count, else: 0
    show_ambi? = ambi_extra?(assigns.ambidextrous, count)
    mark_n = if show_ambi?, do: count * 2, else: count
    patch_d = tire_patch_path(skid_patch_span(mark_n))

    marks =
      if count > 0 do
        Enum.flat_map(0..(count - 1), fn i ->
          one = %{ambi: false, angle: -i * step}

          if show_ambi? do
            [one, %{ambi: true, angle: -i * step - step / 2}]
          else
            [one]
          end
        end)
      else
        []
      end

    displayed = if show_ambi?, do: assigns.ambidextrous, else: assigns.patches
    drive = drive_layout(assigns.chain_ring, assigns.rear_sprocket)

    assigns =
      assigns
      |> assign(:marks, marks)
      |> assign(:patch_d, patch_d)
      |> assign(:show_ambi, show_ambi?)
      |> assign(:displayed, displayed)
      |> assign(:spokes, @spoke_angles)
      |> assign(:hub_holes, @hub_holes)
      |> assign(:cx, @wheel_cx)
      |> assign(:cy, @wheel_cy)
      |> assign(:rim_r, @rim_r)
      |> assign(:spoke_inner, @spoke_inner)
      |> assign(:spoke_outer, @spoke_outer)
      |> assign(:hub_r, @hub_r)
      |> assign(:hub_axle_r, @hub_axle_r)
      |> assign(:hub_petal_r, @hub_petal_r)
      |> assign(:hub_petal_offset, @hub_petal_offset)
      |> assign(:tire_mid, (@tire_outer + @tire_inner) / 2)
      |> assign(:tire_width, @tire_outer - @tire_inner)
      |> assign(:patch_outer, @patch_outer)
      |> assign(:chain_stroke, @chain_stroke)
      |> assign(:drive, drive)

    ~H"""
    <div
      id={@id}
      phx-hook="SkidWheel"
      data-patches={@patches}
      data-ambidextrous={@ambidextrous}
      data-chain-ring={@chain_ring}
      data-rear-sprocket={@rear_sprocket}
      data-cog-pitch={@drive.cog_pitch}
    >
      <div class="flex items-center gap-4">
        <div
          id={"#{@id}-stage-#{@patches}-#{@displayed}-#{@chain_ring}-#{@rear_sprocket}"}
          phx-update="ignore"
          class="skid-wheel-stage relative h-16 w-max shrink-0 [--skid-wheel-h:4rem] sm:h-20 sm:[--skid-wheel-h:5rem]"
        >
          <svg
            viewBox={"0 0 #{@drive.vb_w} 80"}
            class="block h-full w-auto text-base-content"
            aria-hidden="true"
          >
            <g class="skid-wheel-rotor">
              <%!-- Keeps the fill-box centered on the axle when the skid patches are not symmetric. --%>
              <circle
                cx={@cx}
                cy={@cy}
                r={@patch_outer}
                fill="none"
                stroke="none"
              />
              <defs>
                <mask id={"#{@id}-hub-mask"}>
                  <circle cx={@cx} cy={@cy} r={@hub_r + 0.1} fill="white" />
                  <circle cx={@cx} cy={@cy} r={@hub_axle_r} fill="black" />
                  <g
                    :for={angle <- @hub_holes}
                    transform={"rotate(#{angle} #{@cx} #{@cy})"}
                  >
                    <circle
                      cx={@cx}
                      cy={@cy - @hub_petal_offset}
                      r={@hub_petal_r}
                      fill="black"
                    />
                  </g>
                </mask>
              </defs>
              <circle
                cx={@cx}
                cy={@cy}
                r={@tire_mid}
                fill="none"
                stroke="currentColor"
                stroke-width={@tire_width}
                class="opacity-70"
              />
              <circle
                cx={@cx}
                cy={@cy}
                r={@rim_r}
                fill="none"
                stroke="currentColor"
                stroke-width="1.15"
                class="opacity-40"
              />
              <g
                :for={angle <- @spokes}
                transform={"rotate(#{angle} #{@cx} #{@cy})"}
              >
                <line
                  x1={@cx}
                  y1={@cy - @spoke_outer}
                  x2={@cx}
                  y2={@cy - @spoke_inner}
                  stroke="currentColor"
                  stroke-width="0.45"
                  class="opacity-40"
                />
              </g>
              <circle
                cx={@cx}
                cy={@cy}
                r={@hub_r}
                fill="currentColor"
                mask={"url(##{@id}-hub-mask)"}
                class="opacity-90"
              />
              <circle
                cx={@cx}
                cy={@cy}
                r={@hub_r + 0.05}
                fill="none"
                stroke="currentColor"
                stroke-width="0.7"
                class="opacity-70"
              />
              <g
                :for={{mark, index} <- Enum.with_index(@marks)}
                id={"#{@id}-mark-#{index}"}
                class={["skid-patch", mark.ambi && "skid-patch-ambi"]}
                transform={"rotate(#{mark.angle} #{@cx} #{@cy})"}
              >
                <path d={@patch_d} />
              </g>
            </g>
            <g class="skid-wheel-cog">
              <circle
                cx={@drive.cog_cx}
                cy={@cy}
                r={@drive.cog_tip}
                fill="none"
                stroke="none"
              />
              <path
                d={@drive.cog_d}
                fill="currentColor"
                fill-rule="evenodd"
                class="opacity-95"
              />
            </g>
            <g class="skid-wheel-ring">
              <circle
                cx={@drive.ring_cx}
                cy={@cy}
                r={@drive.ring_tip}
                fill="none"
                stroke="none"
              />
              <path
                d={@drive.ring_d}
                fill="currentColor"
                fill-rule="evenodd"
                class="opacity-95"
              />
            </g>
            <path
              class="skid-wheel-chain"
              d={@drive.chain_d}
              fill="none"
              stroke="currentColor"
              stroke-width={@chain_stroke}
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-dasharray={"#{@drive.chain_dash} #{@drive.chain_gap}"}
            />
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

  attr :form, Phoenix.HTML.Form, required: true
  attr :tab, :atom, required: true
  attr :cadence, :integer, required: true

  def cadence_dock(assigns) do
    ~H"""
    <.form
      for={@form}
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
    </.form>
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

    development =
      Calculations.development_m(
        assigns.chain_ring,
        assigns.rear_sprocket,
        assigns.tire_width
      )

    assigns =
      assigns
      |> assign(:ratio, ratio)
      |> assign(:patches, patches)
      |> assign(:speed, speed)
      |> assign(:development, development)

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
        <.stat
          :if={@development}
          hint_id={"hint-development-#{@id_prefix}"}
          label={gettext("Development")}
        >
          <:hint>
            <p>
              {gettext(
                "The distance that the bicycle moves with each revolution of the pedals."
              )}
            </p>
          </:hint>
          <span id={"development-#{@id_prefix}"}>
            {Calculations.format_development(@development)} m
          </span>
        </.stat>
      </dl>

      <.stat
        :if={@ratio}
        hint_id={"hint-ratio-#{@id_prefix}"}
        label={gettext("Ratio")}
      >
        <:hint>
          <p>
            {gettext(
              "The ratio of chainring teeth to rear sprocket teeth, in other words, how many times your rear wheel turns with each revolution of the pedals."
            )}
          </p>
          <ul class="mt-1.5 list-disc space-y-0.5 pl-4">
            <li>{gettext("Under 1.9: bike polo")}</li>
            <li>{gettext("1.9 to 2.3: lots of steep slopes")}</li>
            <li>{gettext("2.3 to 2.7: polyvalent ratio")}</li>
            <li>
              {gettext(
                "2.7 to 3.0: high speed on flat roads (take care of your knees)"
              )}
            </li>
            <li>{gettext("Over 3.0: pisteritx 🔥")}</li>
          </ul>
        </:hint>
        <.ratio_motion
          id={"ratio-motion-#{@id_prefix}"}
          ratio={@ratio}
          cadence={@cadence}
          label={Calculations.format_ratio(@ratio)}
        />
      </.stat>

      <.stat
        :if={@patches}
        hint_id={"hint-skid-patches-#{@id_prefix}"}
        label={gettext("Skid patches")}
      >
        <:hint>
          <p>
            {gettext(
              "While skidding, you always brake with your feet — and the crank — in the same position."
            )}
          </p>
          <p class="mt-1.5">
            {gettext(
              "You can predict how many spots will wear on your rear tire. These spots are called skid patches."
            )}
          </p>
        </:hint>
        <.skid_wheel
          id={"skid-wheel-#{@id_prefix}"}
          patches={@patches.one_sided}
          ambidextrous={@patches.ambidextrous}
          chain_ring={@chain_ring}
          rear_sprocket={@rear_sprocket}
        />
        <.gear_math_credit />
      </.stat>
    </div>
    """
  end

  def gear_math_credit(assigns) do
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
      {gettext("and")}
      <a
        href="https://www.sheldonbrown.com/"
        target="_blank"
        rel="noopener noreferrer"
        class="underline decoration-base-content/25 underline-offset-2 transition hover:text-base-content/70 hover:decoration-base-content/50"
      >
        Sheldon Brown
      </a>
    </p>
    """
  end

  attr :label, :string, required: true
  attr :hint_id, :string, default: nil
  slot :hint
  slot :inner_block, required: true

  def stat(assigns) do
    ~H"""
    <div>
      <dt class="flex items-center gap-1 text-xs tracking-wide text-base-content/50 uppercase">
        <span>{@label}</span>
        <button
          :if={@hint != [] && @hint_id}
          type="button"
          id={"#{@hint_id}-toggle"}
          class="inline-flex rounded-full p-0.5 text-base-content/40 transition hover:bg-base-200 hover:text-base-content/75"
          phx-click={toggle_hint(@hint_id)}
          aria-controls={@hint_id}
          aria-expanded="false"
        >
          <.icon name="hero-information-circle" class="size-3.5" />
          <span class="sr-only">
            {gettext("About %{label}", label: @label)}
          </span>
        </button>
      </dt>
      <div
        :if={@hint != [] && @hint_id}
        id={@hint_id}
        class="grid grid-rows-[0fr] overflow-hidden opacity-0 transition-all duration-300 ease-in-out motion-reduce:transition-none"
      >
        <div class="min-h-0 overflow-hidden">
          <div class="mt-1 text-[11px] leading-snug font-normal tracking-normal text-base-content/65 normal-case">
            {render_slot(@hint)}
          </div>
        </div>
      </div>
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

  defp skid_patch_span(n) when n > 16, do: 7.0
  defp skid_patch_span(n) when n > 10, do: 10.0
  defp skid_patch_span(n) when n > 6, do: 13.0
  defp skid_patch_span(_n), do: 18.0

  defp tire_patch_path(span) do
    half = span / 2
    {x1, y1} = polar(@wheel_cx, @wheel_cy, @patch_outer, -half)
    {x2, y2} = polar(@wheel_cx, @wheel_cy, @patch_outer, half)
    {x3, y3} = polar(@wheel_cx, @wheel_cy, @patch_inner, half)
    {x4, y4} = polar(@wheel_cx, @wheel_cy, @patch_inner, -half)

    "M #{fmt(x1)} #{fmt(y1)} A #{fmt(@patch_outer)} #{fmt(@patch_outer)} 0 0 1 #{fmt(x2)} #{fmt(y2)} L #{fmt(x3)} #{fmt(y3)} A #{fmt(@patch_inner)} #{fmt(@patch_inner)} 0 0 0 #{fmt(x4)} #{fmt(y4)} Z"
  end

  defp drive_layout(chain_ring, rear)
       when is_integer(chain_ring) and is_integer(rear) and chain_ring > 0 and
              rear > 0 do
    cog0 = rear * @pitch_unit
    ring0 = chain_ring * @pitch_unit
    sep = @ring_cx - @cog_cx - @pair_gap

    s_max =
      Enum.min([
        @max_cog_pitch / cog0,
        @max_ring_pitch / ring0,
        sep / (cog0 + ring0)
      ])

    s_min = @min_cog_pitch / cog0

    scale =
      cond do
        s_min > s_max -> s_max
        s_max < 1.0 -> s_max
        s_min > 1.0 -> s_min
        true -> 1.0
      end

    cog_pitch = cog0 * scale
    ring_pitch = ring0 * scale
    cog_tip = cog_pitch + @tooth_addendum
    cog_root = cog_pitch - @tooth_dedendum
    ring_tip = ring_pitch + @tooth_addendum
    ring_root = ring_pitch - @tooth_dedendum
    circular = 2 * :math.pi() * @pitch_unit * scale
    vb_w = @ring_cx + ring_tip + @view_pad

    %{
      cog_pitch: fmt(cog_pitch),
      ring_pitch: fmt(ring_pitch),
      cog_cx: fmt(@cog_cx),
      cog_tip: fmt(cog_tip),
      cog_d: sprocket_d(@cog_cx, @wheel_cy, rear, cog_tip, cog_root, @bore_r),
      ring_cx: fmt(@ring_cx),
      ring_tip: fmt(ring_tip),
      ring_d:
        sprocket_d(
          @ring_cx,
          @wheel_cy,
          chain_ring,
          ring_tip,
          ring_root,
          @bore_r
        ),
      chain_d:
        chain_d(
          @cog_cx,
          @ring_cx,
          @wheel_cy,
          cog_pitch,
          ring_tip + @chain_clear
        ),
      chain_dash: fmt(circular * 0.58),
      chain_gap: fmt(circular * 0.42),
      vb_w: fmt(vb_w)
    }
  end

  defp sprocket_d(cx, cy, teeth, r_tip, r_root, bore) do
    step = 2 * :math.pi() / teeth

    [first | rest] =
      Enum.flat_map(0..(teeth - 1), fn i ->
        a = i * step - :math.pi() / 2

        [
          svg_pt(cx, cy, r_root, a - step * 0.18),
          svg_pt(cx, cy, r_tip, a - step * 0.06),
          svg_pt(cx, cy, r_tip, a + step * 0.06),
          svg_pt(cx, cy, r_root, a + step * 0.18)
        ]
      end)

    outline = "M #{first} " <> Enum.map_join(rest, " ", &"L #{&1}") <> " Z"
    outline <> " " <> circle_d(cx, cy, min(bore, r_root * 0.42))
  end

  # Upper and lower runs are the external tangents. The chainring arc is the
  # outer one (around the right side). The cog arc is the outer one too,
  # toward the hub, so both sprockets turn the same way.
  defp chain_d(cog_cx, ring_cx, cy, r1, r2) do
    dist = ring_cx - cog_cx
    beta = :math.acos(clamp_unit((r1 - r2) / dist))
    cog_up = svg_pt(cog_cx, cy, r1, -beta)
    cog_lo = svg_pt(cog_cx, cy, r1, beta)
    ring_up = svg_pt(ring_cx, cy, r2, -beta)
    ring_lo = svg_pt(ring_cx, cy, r2, beta)
    cog_large = if beta > :math.pi() / 2, do: 0, else: 1
    ring_large = if beta < :math.pi() / 2, do: 0, else: 1

    [
      "M #{cog_up} L #{ring_up}",
      "A #{fmt(r2)} #{fmt(r2)} 0 #{ring_large} 1 #{ring_lo}",
      "L #{cog_lo}",
      "A #{fmt(r1)} #{fmt(r1)} 0 #{cog_large} 0 #{cog_up}"
    ]
    |> Enum.join(" ")
  end

  defp circle_d(cx, cy, r) do
    left = fmt(cx - r)
    right = fmt(cx + r)
    y = fmt(cy)
    radius = fmt(r)

    "M #{left} #{y} A #{radius} #{radius} 0 1 0 #{right} #{y} " <>
      "A #{radius} #{radius} 0 1 0 #{left} #{y}"
  end

  defp clamp_unit(n) when n > 1.0, do: 1.0
  defp clamp_unit(n) when n < -1.0, do: -1.0
  defp clamp_unit(n), do: n

  defp polar(cx, cy, r, deg) do
    rad = deg * :math.pi() / 180.0
    {cx + r * :math.sin(rad), cy - r * :math.cos(rad)}
  end

  defp svg_pt(cx, cy, r, angle) do
    "#{fmt(cx + r * :math.cos(angle))} #{fmt(cy + r * :math.sin(angle))}"
  end

  defp fmt(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 2)
  defp fmt(n) when is_integer(n), do: Integer.to_string(n)

  defp ambi_extra?(ambi, one_sided)
       when is_integer(ambi) and is_integer(one_sided) and ambi > one_sided,
       do: true

  defp ambi_extra?(_ambi, _one_sided), do: false

  defp visual_pedal_seconds(rpm) when is_integer(rpm) and rpm > 0 do
    @seconds_per_minute / rpm
  end

  defp visual_pedal_seconds(_rpm), do: @seconds_per_minute / @reference_rpm

  defp toggle_hint(id) do
    JS.toggle_class("grid-rows-[1fr] opacity-100", to: "##{id}")
    |> JS.toggle_class("grid-rows-[0fr] opacity-0", to: "##{id}")
    |> JS.toggle_attribute({"aria-expanded", "true", "false"})
  end

  defp keep_panel_during_collapse do
    JS.hide(
      time: 300,
      transition:
        {"transition-all duration-300 ease-in-out", "opacity-100",
         "opacity-100"}
    )
  end
end
