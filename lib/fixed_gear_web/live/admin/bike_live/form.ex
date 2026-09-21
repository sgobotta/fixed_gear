defmodule FixedGearWeb.Admin.BikeLive.Form do
  use FixedGearWeb, :live_view

  alias FixedGear.Bikes
  alias FixedGear.Bikes.Bike

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>
          {gettext("Weight is required. Everything else can wait.")}
        </:subtitle>
        <:actions>
          <.button navigate={~p"/admin/bikes"} class="btn-ghost">
            {gettext("Back")}
          </.button>
        </:actions>
      </.header>

      <.form
        for={@form}
        id="bike-form"
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label={gettext("Name")} required />
        <.input field={@form[:owner]} type="text" label={gettext("Owner")} required />
        <.input
          field={@form[:weight_kg]}
          type="number"
          label={gettext("Weight (kg)")}
          step="0.001"
          min="0.001"
          required
        />

        <div class="mt-6 grid gap-4 sm:grid-cols-2">
          <.input
            field={@form[:frame_material]}
            type="select"
            label={gettext("Frame")}
            prompt="—"
            options={material_options()}
          />
          <.input
            field={@form[:frame_name]}
            type="text"
            label={gettext("Frame name")}
          />
          <.input
            field={@form[:handlebar_material]}
            type="select"
            label={gettext("Handlebar")}
            prompt="—"
            options={material_options()}
          />
          <.input
            field={@form[:chain_ring]}
            type="select"
            label={gettext("Chain ring")}
            prompt="—"
            options={Bikes.chain_ring_options()}
          />
          <.input
            field={@form[:rear_sprocket]}
            type="select"
            label={gettext("Rear sprocket")}
            prompt="—"
            options={Bikes.sprocket_options()}
          />
          <.input
            field={@form[:tire_width]}
            type="select"
            label={gettext("Tire")}
            prompt="—"
            options={Bikes.tire_options()}
          />
        </div>

        <div class="mt-6 space-y-3">
          <p class="label mb-1">{gettext("Photo")}</p>
          <.bike_photo
            :if={@bike.id && Bike.photo?(@bike)}
            id="current-photo"
            src={
              ~p"/bikes/#{@bike}/photo?#{[v: DateTime.to_unix(@bike.updated_at)]}"
            }
            alt={gettext("Current photo of %{name}", name: @bike.name)}
          />
          <div id="photo-input" phx-hook="CompressPhoto">
            <.live_file_input
              upload={@uploads.photo}
              accept="image/*"
              capture="environment"
              class="file-input file-input-bordered w-full"
            />
          </div>
          <p class="text-xs text-base-content/55">
            {gettext("Optional. On a phone this opens the camera.")}
          </p>
          <article
            :for={entry <- @uploads.photo.entries}
            id={"upload-#{entry.ref}"}
            class="space-y-2"
          >
            <div class="overflow-hidden rounded-xl bg-base-300">
              <.live_img_preview
                entry={entry}
                class={bike_photo_img_class()}
              />
            </div>
            <progress
              value={entry.progress}
              max="100"
              class="progress w-full"
            >
              {entry.progress}%
            </progress>
            <p
              :if={entry.valid? and not entry.done?}
              class="text-xs text-base-content/55"
            >
              {gettext("Uploading photo...")}
            </p>
            <p
              :for={err <- upload_errors(@uploads.photo, entry)}
              class="text-sm text-error"
            >
              {error_to_string(err)}
            </p>
            <button
              type="button"
              id={"cancel-upload-#{entry.ref}"}
              class="btn btn-ghost btn-sm"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
            >
              {gettext("Remove photo")}
            </button>
          </article>
          <p
            :for={err <- upload_errors(@uploads.photo)}
            class="text-sm text-error"
          >
            {error_to_string(err)}
          </p>
          <p
            :for={msg <- Enum.map(@form[:photo].errors, &translate_error/1)}
            class="text-sm text-error"
          >
            {msg}
          </p>
        </div>

        <footer class="mt-8">
          <.button
            phx-disable-with={gettext("Saving...")}
            class="btn btn-primary"
            id="save-bike"
            disabled={photo_uploading?(@uploads.photo)}
          >
            {gettext("Save bike")}
          </.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:photo,
       accept: ~w(.jpg .jpeg .png .webp image/jpeg image/png image/webp),
       max_entries: 1,
       max_file_size: 15_000_000,
       chunk_timeout: 30_000,
       auto_upload: true
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    bike = %Bike{}

    socket
    |> assign(:page_title, gettext("New bike"))
    |> assign(:bike, bike)
    |> assign(:form, to_form(Bikes.change_bike(bike)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    bike = Bikes.get_bike!(id)

    socket
    |> assign(:page_title, gettext("Edit bike"))
    |> assign(:bike, bike)
    |> assign(:form, to_form(Bikes.change_bike(bike)))
  end

  @impl true
  def handle_event("validate", %{"bike" => bike_params}, socket) do
    form =
      socket.assigns.bike
      |> Bikes.change_bike(bike_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     socket
     |> drop_invalid_photo()
     |> assign(:form, form)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, drop_invalid_photo(socket)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photo, ref)}
  end

  def handle_event("save", %{"bike" => bike_params}, socket) do
    save_bike(socket, socket.assigns.live_action, bike_params)
  end

  defp save_bike(socket, action, bike_params) do
    changeset = Bikes.change_bike(socket.assigns.bike, bike_params)

    if changeset.valid? do
      persist_bike(socket, action, bike_params)
    else
      {:noreply,
       assign(socket, :form, to_form(Map.put(changeset, :action, :validate)))}
    end
  end

  defp persist_bike(socket, :new, bike_params) do
    case Bikes.create_bike(bike_params, consume_photo(socket)) do
      {:ok, _bike} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Bike created"))
         |> push_navigate(to: ~p"/admin/bikes")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp persist_bike(socket, :edit, bike_params) do
    case Bikes.update_bike(
           socket.assigns.bike,
           bike_params,
           consume_photo(socket)
         ) do
      {:ok, _bike} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Bike updated"))
         |> push_navigate(to: ~p"/admin/bikes")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp consume_photo(socket) do
    {done, in_progress} = uploaded_entries(socket, :photo)

    if in_progress == [] do
      case consume_uploaded_entries(socket, :photo, fn %{path: path}, entry ->
             {:ok, {File.read!(path), entry.client_type}}
           end) do
        [photo | _] -> photo
        [] -> nil
      end
    else
      consume_done_photo(socket, done)
    end
  end

  defp consume_done_photo(_socket, []), do: nil

  defp consume_done_photo(socket, [entry | _]) do
    consume_uploaded_entry(socket, entry, fn %{path: path} ->
      {:ok, {File.read!(path), entry.client_type}}
    end)
  end

  defp drop_invalid_photo(socket) do
    Enum.reduce(socket.assigns.uploads.photo.entries, socket, fn entry, acc ->
      errors = upload_errors(acc.assigns.uploads.photo, entry)

      if errors == [] do
        acc
      else
        acc
        |> cancel_upload(:photo, entry.ref)
        |> put_flash(:error, error_to_string(hd(errors)))
      end
    end)
  end

  defp photo_uploading?(upload) do
    Enum.any?(upload.entries, &(&1.valid? and not &1.done?))
  end

  defp error_to_string(:too_large), do: gettext("Photo is too large")

  defp error_to_string(:too_many_files),
    do: gettext("Only one photo is allowed")

  defp error_to_string(:not_accepted), do: gettext("Use JPEG, PNG, or WebP")
  defp error_to_string(_), do: gettext("Could not upload photo")

  defp material_options do
    [
      {gettext("Aluminum"), :aluminum},
      {gettext("Steel"), :steel},
      {gettext("Carbon fiber"), :carbon_fiber}
    ]
  end
end
