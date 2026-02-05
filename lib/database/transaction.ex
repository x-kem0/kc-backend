defmodule KC.Transaction do
  @moduledoc false
  defstruct action: nil, changeset: nil, module: nil

  def parse(transactions) when is_list(transactions) do
    for transaction <- transactions do
      parse(transaction)
    end
  end

  def parse(transaction) when is_map(transaction) do
    action =
      case Map.get(transaction, "action") do
        "create" -> {:ok, :create}
        "update" -> {:ok, :update}
        "delete" -> {:ok, :delete}
        nil -> {:error, "no action"}
        _ -> {:error, "invalid action"}
      end

    object =
      case Map.get(transaction, "object") do
        "chapter" -> {:ok, KC.Chapter}
        "page" -> {:ok, KC.Page}
        nil -> {:error, "no object"}
        _ -> {:error, "invalid object"}
      end

    data =
      case Map.get(transaction, "data") do
        nil -> {:error, "no data"}
        %{} = data -> {:ok, data}
        _ -> {:error, "invalid data"}
      end

    with {:ok, action} <- action,
         {:ok, module} <- object,
         {:ok, params} <- data do
      case_result =
        case action do
          :update ->
            %{"id" => id} = params
            params = Map.delete(params, "id")

            module
            |> struct(%{id: id})
            |> module.changeset(params)

          :delete ->
            %{"id" => id} = params
            params = Map.delete(params, "id")

            module
            |> struct(%{id: id})
            |> module.changeset(params)

          _ ->
            module
            |> struct(%{})
            |> module.changeset(params)
        end

      changeset = module.changeset(case_result, params)

      if changeset.valid? do
        {:ok, %__MODULE__{action: action, changeset: changeset, module: module}}
      else
        {:error, "invalid changeset"}
      end
    end
  end

  def parse(_) do
    {:error, "invalid format"}
  end

  def process(%__MODULE__{} = transaction) do
    process([transaction])
  end

  def process(transactions) when is_list(transactions) do
    process(transactions, Ecto.Multi.new(), [], [])
  end

  def process([%__MODULE__{} = transaction | tail], multi, uploads, deletes) do
    {changeset, new_uploads, new_deletes} = transaction.module.apply_files(transaction.action, transaction.changeset)

    multi =
      case transaction.action do
        :create ->
          Ecto.Multi.insert(multi, Ecto.UUID.generate(), changeset)

        :update ->
          Ecto.Multi.update(multi, Ecto.UUID.generate(), changeset)

        :delete ->
          Ecto.Multi.delete(multi, Ecto.UUID.generate(), changeset)
      end

    process(tail, multi, new_uploads ++ uploads, new_deletes ++ deletes)
  end

  def process([], multi, uploads, deletes) do
    for {id, bytes, original_filename, mime_type} <- uploads do
      :logger.info("Uploading file #{id}")
      S3.upload(bytes, id, original_filename, mime_type)
    end

    KC.Repo.transact(multi)

    KC.API.IndexCache.rebuild_index()

    for id <- deletes do
      :logger.info("Deleting file #{id}")
    end

    :ok
  rescue
    e in Postgrex.Error ->
      for {id, _bytes, _original_filename, _mime_type} <- uploads do
        :logger.info("Deleting file #{id}")
        S3.delete(id)
      end

      {:error, String.replace(e.postgres.message, "\"", "'")}
  end
end
