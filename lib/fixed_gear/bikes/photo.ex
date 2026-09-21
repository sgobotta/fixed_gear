defmodule FixedGear.Bikes.Photo do
  @moduledoc false

  @allowed_types ~w(image/jpeg image/png image/webp)

  def identify(<<0xFF, 0xD8, 0xFF, _rest::binary>>), do: {:ok, "image/jpeg"}

  def identify(
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>>
      ),
      do: {:ok, "image/png"}

  def identify(<<"RIFF", _size::little-32, "WEBP", _rest::binary>>),
    do: {:ok, "image/webp"}

  def identify(_data), do: :error

  def serve_content_type(data, claimed_type)
      when is_binary(data) and is_binary(claimed_type) do
    case identify(data) do
      {:ok, detected}
      when claimed_type in @allowed_types and claimed_type == detected ->
        {:ok, detected}

      _ ->
        :error
    end
  end

  def serve_content_type(_data, _claimed_type), do: :error
end
