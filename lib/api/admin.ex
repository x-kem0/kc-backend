defmodule KC.API.Admin do
  # base route: /api/admin/
  @moduledoc false
  use Plug.Router

  import Ecto.Query

  defp session_check(conn, _params) do
    expected_csrf_token =
      case get_req_header(conn, "kc-csrf-token") do
        [t] -> t
        _ -> :not_found
      end

    valid = get_session(conn, :valid) && get_session(conn, :csrf) == expected_csrf_token

    if valid do
      conn
    else
      conn
      |> send_resp(401, ~s({"error": "authentication failed; check session & CSRF"}))
      |> halt()
    end
  end

  plug :match
  plug :session_check
  plug :dispatch

  get "/whoami" do
    session =
      conn
      |> get_session()
      |> JSON.encode!()

    send_resp(conn, 200, session)
  end

  get "/chapter/list" do
    chapters =
      from(
        c in KC.Chapter,
        order_by: [asc: c.idx]
      )
      |> KC.Repo.all()
      |> Enum.map(&Map.put(&1, :pages, []))
      |> JSON.encode!()

    send_resp(conn, 200, chapters)
  end

  get "/chapter/:id" do
    %{
      "id" => chapter_id
    } = conn.params

    chapter = KC.Repo.get_by(KC.Chapter, id: chapter_id)

    case chapter do
      %{} ->
        page_query =
          from(
            p in KC.Page,
            order_by: [asc: p.idx]
          )

        json =
          from(
            c in KC.Chapter,
            where: c.id == ^chapter.id,
            order_by: [asc: c.idx],
            preload: [pages: ^page_query]
          )
          |> KC.Repo.all()
          |> List.first()
          |> JSON.encode!()

        send_resp(conn, 200, json)

      _ ->
        send_resp(conn, 404, "")
    end
  end

  post "/transaction" do
    transactions =
      case conn.params do
        %{"_json" => t} ->
          KC.Transaction.parse(t)

        _ ->
          {:error, "invalid body"}
      end

    result =
      with nil <- Enum.find(transactions, &match?({:error, _}, &1)) do
        transactions
        |> Enum.map(fn t ->
          {:ok, t} = t
          t
        end)
        |> KC.Transaction.process()
      end

    case result do
      {:error, reason} ->
        resp = JSON.encode!(%{"error" => reason})
        send_resp(conn, 400, resp)

      :ok ->
        send_resp(conn, 200, "")
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
