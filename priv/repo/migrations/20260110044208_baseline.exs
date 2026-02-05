defmodule KC.Repo.Migrations.Baseline do
  use Ecto.Migration

  def change do
    create table(:chapters) do
      add :idx, :integer, null: false
      add :title, :string, null: false
      add :active, :boolean, null: false
      add :banner_s3_file, :string, null: false
      timestamps()
    end

    create table(:pages) do
      add :chapter_id,
          references(:chapters, on_delete: :delete_all),
          null: false

      add :idx, :integer, null: false
      add :filename, :string, null: false
      add :thumbnail_s3_file, :string, null: false
      add :s3_file, :string, null: false
      timestamps()
    end

    create table(:admins) do
      add :email, :string, null: false
      timestamps()
    end
  end
end
