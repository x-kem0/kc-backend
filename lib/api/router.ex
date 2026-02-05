defmodule KC.API.Router do
  use Plug.Router

  import Ecto.Query

  alias KC.API.IndexCache

  def get_conf(keyword) do
    :kc_core |> Application.fetch_env!(KC.API) |> Keyword.fetch!(keyword)
  end

  defp put_skb(conn, _params) do
    put_in(conn.secret_key_base, get_conf(:secret_key_base))
  end

  defp kc_api_plug(conn, _params) do
    conn
    |> fetch_query_params()
    |> fetch_cookies()
    |> fetch_session()
    |> put_resp_header("Content-Type", "application/json")
  end

  defp check_method(conn, _params) do
    case conn.method do
      "GET" ->
        conn

      "POST" ->
        conn

      _ ->
        conn
        |> send_resp(405, ~s({"error": "method not allowed"}))
        |> halt()
    end
  end

  plug :match
  plug :put_skb

  plug Plug.Session,
    store: :cookie,
    key: "kc_session",
    signing_salt: {__MODULE__, :get_conf, [:signing_salt]},
    encryption_salt: {__MODULE__, :get_conf, [:encryption_salt]},
    log: :debug

  plug :kc_api_plug
  plug :check_method

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: JSON

  plug :dispatch

  get "/api" do
    send_resp(conn, 200, "")
  end

  get "/api/file/:id" do
    %{
      "id" => file_id
    } = conn.params

    url = S3.presigned_get_url(file_id)

    conn
    |> put_resp_header("Location", url)
    |> send_resp(302, "")
  end

  get "/api/chapter/list" do
    chapters =
      from(
        c in KC.Chapter,
        where: c.active,
        order_by: [asc: c.idx]
      )
      |> KC.Repo.all()
      |> Enum.map(&Map.put(&1, :pages, []))
      |> JSON.encode!()

    send_resp(conn, 200, chapters)
  end

  get "/api/chapter/:id" do
    %{
      "id" => chapter_id
    } = conn.params

    chapter = KC.Repo.get_by(KC.Chapter, id: chapter_id)

    case chapter do
      %{active: true} ->
        json =
          chapter
          |> KC.Repo.preload([:pages])
          |> JSON.encode!()

        send_resp(conn, 200, json)

      _ ->
        send_resp(conn, 404, "")
    end
  end

  get "/api/chapter/idx/:id" do
    %{
      "id" => chapter_id
    } = conn.params

    chapter = KC.Repo.get_by(KC.Chapter, id: chapter_id)

    case chapter do
      %{active: true} ->
        json =
          chapter
          |> KC.Repo.preload([:pages])
          |> JSON.encode!()

        send_resp(conn, 200, json)

      _ ->
        send_resp(conn, 404, "")
    end
  end

  get "/api/chapter/idx/:chapter_id/:page_id" do
    %{
      "chapter_id" => chapter_idx,
      "page_id" => page_idx
    } = conn.params

    details = IndexCache.get_page(chapter_idx, page_idx)

    case details do
      nil ->
        send_resp(conn, 404, "")

      %{id: id, next: next, prev: prev} ->
        next =
          if next do
            String.replace(next, "_", "/")
          end

        prev =
          if prev do
            String.replace(prev, "_", "/")
          end

        page = KC.Repo.get_by(KC.Page, id: id)
        chapter = KC.Chapter |> KC.Repo.get_by(id: page.chapter_id) |> Map.put(:pages, [])

        json = JSON.encode!(%{page: page, chapter: chapter, next: next, prev: prev})

        send_resp(conn, 200, json)
    end
  end

  post "/api/auth" do
    csrf_token = 8 |> :crypto.strong_rand_bytes() |> Base.encode64(padding: false)

    conn
    |> put_session(:valid, true)
    |> put_session(:csrf, csrf_token)
    |> put_resp_cookie("kc_csrf_token", csrf_token, same_site: "Strict", http_only: false)
    |> send_resp(200, "")
  end

  forward("/api/admin", to: KC.API.Admin)

  match _ do
    send_resp(conn, 404, "")
  end
end
