defmodule FixedGearWeb.RankingComponents do
  @moduledoc false

  use Phoenix.Component

  import FixedGearWeb.CoreComponents, only: [icon: 1]

  alias Phoenix.LiveView.JS

  @max_skid_ticks 24
  @reference_rpm 90
  @seconds_per_minute 60

  attr :id, :string, required: true
  attr :expanded, :boolean, required: true
  attr :toggle_event, :string, default: "toggle_expand"
  attr :toggle_key, :any, required: true
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
        <div
          id={"#{@id}-header"}
          role="button"
          tabindex="0"
          phx-click={@toggle_event}
          phx-keydown={JS.dispatch("click")}
          phx-key="Enter"
          onkeydown="if (event.key === ' ') { event.preventDefault(); event.currentTarget.click() }"
          phx-value-key={@toggle_key}
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
            {if @expanded, do: "Collapse", else: "Expand"}
          </span>
        </div>

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

  attr :id, :string, required: true
  attr :patches, :integer, required: true
  attr :ambidextrous, :integer, default: nil
  attr :cadence, :integer, required: true
  attr :ratio, :float, required: true

  def skid_wheel(assigns) do
    count =
      if assigns.patches in 1..@max_skid_ticks do
        assigns.patches
      else
        0
      end

    step = if count > 0, do: 360 / count, else: 0
    blob_rx = skid_blob_rx(count)
    blob_ry = blob_rx * 0.78

    marks =
      if count > 0 do
        Enum.map(0..(count - 1), fn i ->
          %{
            index: i,
            angle: -i * step,
            rx: blob_rx,
            ry: blob_ry
          }
        end)
      else
        []
      end

    assigns =
      assigns
      |> assign(:marks, marks)
      |> assign(:spokes, [0, 120, 240])
      |> assign(:rev_ms, visual_rev_ms(assigns.cadence, assigns.ratio))

    ~H"""
    <div
      id={@id}
      phx-hook="SkidWheel"
      data-patches={@patches}
      data-cadence={@cadence}
      data-rev-ms={@rev_ms}
    >
      <div class="flex items-center gap-4">
        <div
          id={"#{@id}-stage"}
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
                y1="33"
                x2="40"
                y2="18"
                stroke="currentColor"
                stroke-width="3.5"
                stroke-linecap="round"
                class="opacity-30"
              />
            </g>
            <circle cx="40" cy="40" r="5.5" fill="currentColor" class="opacity-40" />
            <g
              :for={mark <- @marks}
              class="skid-patch"
              data-index={mark.index}
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
        <p class="font-mono text-lg leading-none font-semibold tabular-nums">
          {@patches}
        </p>
      </div>
      <p class="mt-1 ps-20 text-xs text-base-content/55 sm:ps-24">
        marks on the tire
        <span :if={@ambidextrous} class="block">{@ambidextrous} both feet</span>
      </p>
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
      class="flex items-end gap-4"
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
            Pedal
          </span>
        </div>

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
            Wheel
          </span>
        </div>
      </div>
      <div class="flex min-w-0 flex-col gap-1">
        <div class="flex h-14 items-center sm:h-16">
          <p class="font-mono text-lg leading-none font-semibold tabular-nums">
            {@label}
          </p>
        </div>
        <p class="text-[11px] leading-none text-base-content/55">
          wheel turns per pedal stroke
        </p>
      </div>
    </div>
    """
  end

  defp skid_blob_rx(n) when n > 12, do: 3.8
  defp skid_blob_rx(n) when n > 6, do: 4.7
  defp skid_blob_rx(_n), do: 5.6

  defp visual_pedal_seconds(rpm) when is_integer(rpm) and rpm > 0 do
    @seconds_per_minute / rpm
  end

  defp visual_pedal_seconds(_rpm), do: @seconds_per_minute / @reference_rpm

  defp visual_rev_ms(rpm, ratio) when is_number(ratio) and ratio > 0 do
    round(visual_pedal_seconds(rpm) / ratio * 1000)
  end

  defp visual_rev_ms(rpm, _ratio), do: round(visual_pedal_seconds(rpm) * 1000)

  defp keep_panel_during_collapse do
    JS.hide(
      time: 300,
      transition:
        {"transition-all duration-300 ease-in-out", "opacity-100",
         "opacity-100"}
    )
  end
end
