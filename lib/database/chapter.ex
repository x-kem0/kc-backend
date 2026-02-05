defmodule KC.Chapter do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @derive {JSON.Encoder, except: [:__meta__, :upload_b64, :upload_filename]}
  schema "chapters" do
    field :idx, :integer
    field :title, :string
    field :active, :boolean
    field :banner_s3_file

    field :upload_b64, :string, virtual: true
    field :upload_filename, :string, virtual: true

    has_many :pages, KC.Page
    timestamps()
  end

  def changeset(chapter, params \\ %{}) do
    cast(chapter, params, [:id, :idx, :title, :active, :banner_s3_file, :upload_b64, :upload_filename])
  end

  def apply_files(:create, changeset) do
    case changeset do
      %{changes: %{upload_b64: data, upload_filename: filename}} ->
        data = Base.decode64!(data, padding: false)
        {:ok, mime_type} = MrMIME.identify_bytes_with_name(data, filename)
        file_uuid = Ecto.UUID.generate()
        uploads = [{file_uuid, data, filename, mime_type}]
        changeset = put_change(changeset, :banner_s3_file, file_uuid)
        {changeset, uploads, []}

      _ ->
        {changeset, [], []}
    end
  end

  def apply_files(:update, changeset) do
    case changeset do
      %{changes: %{upload_b64: data, upload_filename: filename}} ->
        %{
          banner_s3_file: s3_to_delete
        } = KC.Repo.get_by(KC.Chapter, id: changeset.data.id)

        data = Base.decode64!(data, padding: false)
        {:ok, mime_type} = MrMIME.identify_bytes_with_name(data, filename)
        file_uuid = Ecto.UUID.generate()
        uploads = [{file_uuid, data, filename, mime_type}]
        changeset = put_change(changeset, :banner_s3_file, file_uuid)

        {changeset, uploads, [s3_to_delete]}

      _ ->
        {changeset, [], []}
    end
  end

  def apply_files(:delete, changeset) do
    %{
      banner_s3_file: s3_to_delete
    } = KC.Repo.get_by(KC.Chapter, id: changeset.data.id)

    {changeset, [], [s3_to_delete]}
  end
end
