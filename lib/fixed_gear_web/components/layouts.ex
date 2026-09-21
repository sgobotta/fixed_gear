defmodule FixedGearWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FixedGearWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :section, :atom,
    default: nil,
    doc: "active bottom-nav section: :ranking, :skid_patch, or nil"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="border-b border-base-300/80 px-4 sm:px-6 lg:px-8">
      <div class="mx-auto flex max-w-4xl items-center justify-between gap-4 py-4">
        <.link navigate={~p"/ranking"} class="group flex items-center gap-2">
          <span class="text-sm font-semibold tracking-[0.2em] uppercase">
            Fixed Gear
          </span>
        </.link>
        <nav class="flex items-center gap-3 text-sm">
          <.link
            :if={@current_scope && @current_scope.user}
            navigate={~p"/admin/bikes"}
            class="rounded-full px-3 py-1.5 transition hover:bg-base-200"
          >
            {gettext("Admin")}
          </.link>
          <.link
            :if={@current_scope && @current_scope.user}
            href={~p"/users/settings"}
            class="hidden sm:inline rounded-full px-3 py-1.5 transition hover:bg-base-200"
          >
            {@current_scope.user.email}
          </.link>
          <.link
            :if={@current_scope && @current_scope.user}
            href={~p"/users/log-out"}
            method="delete"
            class="rounded-full px-3 py-1.5 transition hover:bg-base-200"
          >
            {gettext("Log out")}
          </.link>
          <.theme_toggle />
        </nav>
      </div>
    </header>

    <main class="px-4 pt-10 pb-36 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-4xl space-y-6">
        {render_slot(@inner_block)}
      </div>
    </main>

    <nav
      id="app-bottom-nav"
      class="fixed inset-x-0 bottom-0 z-30 border-t border-base-300/80 bg-base-100/95 backdrop-blur pb-[env(safe-area-inset-bottom)]"
    >
      <div class="mx-auto flex max-w-4xl">
        <.link
          id="nav-ranking"
          navigate={~p"/ranking"}
          aria-current={@section == :ranking && "page"}
          class={nav_tab_class(@section == :ranking)}
        >
          <.icon name="hero-bars-3" class="size-5" />
          {gettext("Ranking")}
        </.link>
        <.link
          id="nav-skid-patch"
          navigate={~p"/skid-patch"}
          aria-current={@section == :skid_patch && "page"}
          class={nav_tab_class(@section == :skid_patch)}
        >
          <.nav_wheel_icon />
          {gettext("Skid Patch")}
        </.link>
      </div>
    </nav>

    <.flash_group flash={@flash} />
    """
  end

  defp nav_tab_class(true),
    do:
      "mx-2 flex flex-1 flex-col items-center gap-0.5 rounded-2xl bg-base-200 py-2.5 text-xs font-semibold text-base-content transition"

  defp nav_tab_class(false),
    do:
      "mx-2 flex flex-1 flex-col items-center gap-0.5 rounded-2xl py-2.5 text-xs text-base-content/45 transition hover:text-base-content"

  defp nav_wheel_icon(assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      class="size-5"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="8.2" />
      <circle cx="12" cy="12" r="2.2" />
    </svg>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :id, :string,
    default: "flash-group",
    doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon
          name="hero-computer-desktop-micro"
          class="size-4 opacity-75 hover:opacity-100"
        />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
