defmodule S3 do
  @moduledoc false

  defp bucket do
    :kc_core |> Application.fetch_env!(S3) |> Keyword.fetch!(:bucket)
  end

  def presigned_get_url(file) do
    {:ok, url} =
      :s3
      |> ExAws.Config.new([])
      |> ExAws.S3.presigned_url(:get, bucket(), file)

    url
  end

  def upload(bytes, filename, original_filename, mime_type) do
    bucket()
    |> ExAws.S3.put_object(filename, bytes,
      content_type: mime_type,
      disposition: "attachment;filename=#{original_filename}"
    )
    |> ExAws.request()
  end

  def delete(filename) do
    bucket()
    |> ExAws.S3.delete_object(filename)
    |> ExAws.request()
  end
end
