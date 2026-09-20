defmodule FixedGearWeb.RankingComponents do
  @moduledoc false

  use Phoenix.Component

  import FixedGearWeb.CoreComponents, only: [icon: 1]

  alias Phoenix.LiveView.JS

  attr :id, :string, required: true
  attr :expanded, :boolean, required: true
  attr :toggle_event, :string, default: "toggle_expand"
  attr :toggle_key, :any, required: true
  attr :content_class, :string, default: nil

  slot :leading
  slot :title, required: true
  slot :subtitle
  slot :meta
  slot :content, required: true

  def expandable_list_row(assigns) do
    ~H"""
    <div id={@id} class="flex min-w-0 flex-col px-4 py-4 sm:px-5">
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
        class="flex min-w-0 cursor-pointer items-center gap-4"
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

        <span class="inline-flex shrink-0 text-base-content/40" aria-hidden="true">
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

  defp keep_panel_during_collapse do
    JS.hide(
      time: 300,
      transition:
        {"transition-all duration-300 ease-in-out", "opacity-100",
         "opacity-100"}
    )
  end
end
