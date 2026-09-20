defmodule FixedGearWeb.RankingComponents do
  @moduledoc false

  use Phoenix.Component

  import FixedGearWeb.CoreComponents, only: [icon: 1]

  alias Phoenix.LiveView.JS

  @max_skid_ticks 24
  @pedal_seconds 2.5

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

  def skid_wheel(assigns) do
    ticks =
      if assigns.patches in 1..@max_skid_ticks do
        Enum.map(0..(assigns.patches - 1), fn i ->
          i * 360 / assigns.patches
        end)
      else
        []
      end

    assigns = assign(assigns, :ticks, ticks)

    ~H"""
    <div id={@id} class="flex items-center gap-3">
      <svg
        viewBox="0 0 80 80"
        class="size-20 shrink-0 text-base-content"
        aria-hidden="true"
      >
        <circle
          cx="40"
          cy="40"
          r="28"
          fill="none"
          stroke="currentColor"
          stroke-width="6"
          class="opacity-80"
        />
        <circle cx="40" cy="40" r="6" fill="currentColor" class="opacity-40" />
        <line
          :for={angle <- @ticks}
          x1="40"
          y1="16"
          x2="40"
          y2="28"
          stroke="currentColor"
          stroke-width="3"
          stroke-linecap="round"
          transform={"rotate(#{angle} 40 40)"}
        />
      </svg>
      <div>
        <p class="font-mono text-lg font-semibold tabular-nums">
          {@patches}
        </p>
        <p class="text-xs text-base-content/55">marks on the tire</p>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :ratio, :float, required: true
  attr :label, :string, required: true

  def ratio_motion(assigns) do
    wheel_seconds = @pedal_seconds / assigns.ratio

    assigns =
      assigns
      |> assign(:pedal_seconds, @pedal_seconds)
      |> assign(
        :wheel_duration,
        :erlang.float_to_binary(wheel_seconds, decimals: 2)
      )

    ~H"""
    <div id={@id} class="flex flex-wrap items-center gap-5">
      <div class="flex items-center gap-4">
        <div class="flex flex-col items-center gap-1">
          <svg
            viewBox="0 0 64 64"
            class="size-14 origin-center animate-spin motion-reduce:animate-none"
            style={"animation-duration: #{@pedal_seconds}s; animation-timing-function: linear;"}
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
          <span class="text-[11px] tracking-wide text-base-content/55 uppercase">
            Pedal
          </span>
        </div>

        <div class="flex flex-col items-center gap-1">
          <svg
            viewBox="0 0 64 64"
            class="size-16 origin-center animate-spin motion-reduce:animate-none"
            style={"animation-duration: #{@wheel_duration}s; animation-timing-function: linear;"}
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
          <span class="text-[11px] tracking-wide text-base-content/55 uppercase">
            Wheel
          </span>
        </div>
      </div>
      <p class="max-w-[12rem] text-sm text-base-content/70">
        <span class="font-mono font-semibold tabular-nums">{@label}</span>
        wheel turns per pedal stroke
      </p>
    </div>
    """
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
