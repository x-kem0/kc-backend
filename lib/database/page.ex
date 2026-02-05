defmodule KC.Page do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @derive {JSON.Encoder, except: [:__meta__, :upload_b64, :upload_filename, :chapter]}
  schema "pages" do
    field :idx, :integer
    field :thumbnail_s3_file, :string
    field :s3_file, :string
    field :filename, :string

    field :upload_b64, :string, virtual: true
    field :upload_filename, :string, virtual: true

    belongs_to :chapter, KC.Chapter
    timestamps()
  end

  def changeset(page, params \\ %{}) do
    cast(page, params, [:id, :idx, :thumbnail_s3_file, :s3_file, :chapter_id, :upload_b64, :upload_filename])
  end

  def apply_files(:delete, changeset) do
    %{
      s3_file: file1,
      thumbnail_s3_file: file2
    } = KC.Repo.get_by(KC.Page, id: changeset.data.id)

    {changeset, [], [file1, file2]}
  end

  def apply_files(_action, changeset) do
    case changeset do
      %{changes: %{upload_b64: data, upload_filename: filename}} ->
        data = Base.decode64!(data, padding: false)
        {:ok, mime_type} = MrMIME.identify_bytes_with_name(data, filename)

        {:ok, thumb_bytes} = Thumbp.create(data, 512, 512)

        file_uuid = Ecto.UUID.generate()
        thumb_uuid = Ecto.UUID.generate()

        uploads = [
          {file_uuid, data, filename, mime_type},
          {thumb_uuid, thumb_bytes, "#{filename}.webp", "image/webp"}
        ]

        changeset =
          changeset
          |> put_change(:filename, filename)
          |> put_change(:s3_file, file_uuid)
          |> put_change(:thumbnail_s3_file, thumb_uuid)

        {changeset, uploads, []}

      _ ->
        {changeset, [], []}
    end
  end
end
