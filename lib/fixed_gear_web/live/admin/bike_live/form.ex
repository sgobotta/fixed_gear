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
          <.button
            :if={@live_action == :edit}
            id="delete-bike"
            class="btn-ghost text-error"
            phx-click="delete"
            data-confirm={
              gettext("Delete %{name}? This cannot be undone.", name: @bike.name)
            }
          >
            {gettext("Delete bike")}
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
          <div id="photo-input" phx-hook="CompressPhoto" class="flex flex-col gap-2">
            <label
              id="take-photo"
              class={[
                "btn btn-outline w-full gap-2",
                photo_uploading?(@uploads) && "btn-disabled"
              ]}
            >
              <.live_file_input
                upload={@uploads.camera}
                accept="image/*"
                capture="environment"
                class="sr-only"
              />
              <.icon name="hero-camera" class="size-5" />
              {gettext("Take photo")}
            </label>
            <label
              id="pick-photo"
              class={[
                "btn btn-outline w-full gap-2",
                photo_uploading?(@uploads) && "btn-disabled"
              ]}
            >
              <.live_file_input
                upload={@uploads.photo}
                accept="image/*"
                class="sr-only"
              />
              <.icon name="hero-photo" class="size-5" />
              {gettext("Choose from gallery")}
            </label>
          </div>
          <p class="text-xs text-base-content/55">
            {gettext("Optional.")}
          </p>
          <article
            :for={{upload, entry} <- photo_entries(@uploads)}
            id={"upload-#{upload.name}-#{entry.ref}"}
            class="space-y-2"
          >
            <div class={bike_photo_frame_class()}>
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
              :for={err <- upload_errors(upload, entry)}
              class="text-sm text-error"
            >
              {error_to_string(err)}
            </p>
            <button
              type="button"
              id={"cancel-upload-#{upload.name}-#{entry.ref}"}
              class="btn btn-ghost btn-sm"
              phx-click="cancel-upload"
              phx-value-upload={upload.name}
              phx-value-ref={entry.ref}
            >
              {gettext("Remove photo")}
            </button>
          </article>
          <p
            :for={{_upload, err} <- photo_upload_errors(@uploads)}
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
            disabled={photo_uploading?(@uploads)}
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
    opts = [
      accept: ~w(.jpg .jpeg .png .webp image/jpeg image/png image/webp),
      max_entries: 1,
      max_file_size: 15_000_000,
      chunk_timeout: 30_000,
      auto_upload: true
    ]

    {:ok,
     socket
     |> allow_upload(:camera, opts)
     |> allow_upload(:photo, opts)
     |> assign(:photo_refs, %{camera: [], photo: []})}
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
     |> settle_photos()
     |> assign(:form, form)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, settle_photos(socket)}
  end

  def handle_event(
        "cancel-upload",
        %{"ref" => ref, "upload" => "camera"},
        socket
      ) do
    {:noreply, socket |> cancel_upload(:camera, ref) |> remember_photo_refs()}
  end

  def handle_event(
        "cancel-upload",
        %{"ref" => ref, "upload" => "photo"},
        socket
      ) do
    {:noreply, socket |> cancel_upload(:photo, ref) |> remember_photo_refs()}
  end

  def handle_event("save", %{"bike" => bike_params}, socket) do
    save_bike(settle_photos(socket), socket.assigns.live_action, bike_params)
  end

  def handle_event("delete", _params, socket) do
    case Bikes.delete_bike(socket.assigns.bike) do
      {:ok, _bike} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Bike deleted"))
         |> push_navigate(to: ~p"/admin/bikes")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Bike no longer exists"))
         |> push_navigate(to: ~p"/admin/bikes")}
    end
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
    case consume_named(socket, :camera) do
      nil -> consume_named(socket, :photo)
      photo -> photo
    end
  end

  defp consume_named(socket, name) do
    {done, in_progress} = uploaded_entries(socket, name)

    if in_progress == [] do
      case consume_uploaded_entries(socket, name, fn %{path: path}, entry ->
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

  defp settle_photos(socket) do
    socket
    |> choose_one_photo()
    |> drop_invalid_photo()
    |> remember_photo_refs()
  end

  defp choose_one_photo(socket) do
    prev = socket.assigns.photo_refs
    camera_refs = entry_refs(socket, :camera)
    gallery_refs = entry_refs(socket, :photo)

    cond do
      camera_refs -- prev.camera != [] ->
        cancel_entries(socket, :photo)

      gallery_refs -- prev.photo != [] ->
        cancel_entries(socket, :camera)

      true ->
        socket
    end
  end

  defp cancel_entries(socket, name) do
    Enum.reduce(entry_refs(socket, name), socket, fn ref, acc ->
      cancel_upload(acc, name, ref)
    end)
  end

  defp remember_photo_refs(socket) do
    assign(socket, :photo_refs, %{
      camera: entry_refs(socket, :camera),
      photo: entry_refs(socket, :photo)
    })
  end

  defp entry_refs(socket, name) do
    Enum.map(socket.assigns.uploads[name].entries, & &1.ref)
  end

  defp drop_invalid_photo(socket) do
    Enum.reduce([:camera, :photo], socket, fn name, acc ->
      Enum.reduce(acc.assigns.uploads[name].entries, acc, fn entry, inner ->
        errors = upload_errors(inner.assigns.uploads[name], entry)

        if errors == [] do
          inner
        else
          inner
          |> cancel_upload(name, entry.ref)
          |> put_flash(:error, error_to_string(hd(errors)))
        end
      end)
    end)
  end

  defp photo_entries(uploads) do
    Enum.flat_map([:camera, :photo], fn name ->
      upload = Map.fetch!(uploads, name)
      Enum.map(upload.entries, &{upload, &1})
    end)
  end

  defp photo_upload_errors(uploads) do
    Enum.flat_map([:camera, :photo], fn name ->
      upload = Map.fetch!(uploads, name)
      Enum.map(upload_errors(upload), &{upload, &1})
    end)
  end

  defp photo_uploading?(uploads) do
    Enum.any?([:camera, :photo], fn name ->
      Enum.any?(
        Map.fetch!(uploads, name).entries,
        &(&1.valid? and not &1.done?)
      )
    end)
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
