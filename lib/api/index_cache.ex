defmodule KC.API.IndexCache do
  @moduledoc false
  use GenServer

  import Ecto.Query

  def get_chapter(idx) do
    GenServer.call(__MODULE__, {:get_ch_idx, idx})
  end

  def get_page(ch_idx, pg_idx) do
    GenServer.call(__MODULE__, {:get_page_idx, ch_idx, pg_idx})
  end

  def rebuild_index do
    GenServer.cast(__MODULE__, :rebuild)
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    {:ok, nil, {:continue, :initialize}}
  end

  defp refresh_indices do
    page_preload_query =
      from(p in KC.Page,
        order_by: [asc: p.idx]
      )

    chapters =
      KC.Repo.all(
        from(c in KC.Chapter,
          where: c.active,
          order_by: [asc: c.idx],
          preload: [pages: ^page_preload_query]
        )
      )

    {state, _} =
      Enum.reduce(chapters, {%{}, 1}, fn ch, {acc, ch_idx} ->
        ch_idx_s = to_string(ch_idx)
        acc = Map.put(acc, ch_idx_s, ch.id)

        {acc, _} =
          Enum.reduce(ch.pages, {acc, 1}, fn page, {acc, pg_idx} ->
            pg_idx_s = to_string(pg_idx)
            acc = Map.put(acc, "#{ch_idx_s}_#{pg_idx_s}", page.id)
            {acc, pg_idx + 1}
          end)

        {acc, ch_idx + 1}
      end)

    {pages, _, chapter_keys} =
      Enum.reduce(Map.keys(state), {%{}, nil, []}, fn key, {acc, prev, chapter_acc} ->
        if(length(String.split(key, "_")) == 1) do
          {acc, prev, [key | chapter_acc]}
        else
          acc =
            case prev do
              nil ->
                Map.put(acc, key, %{id: state[key], prev: prev, next: nil})

              _ ->
                p =
                  acc
                  |> Map.get(prev)
                  |> Map.put(:next, key)

                acc
                |> Map.put(key, %{id: state[key], prev: prev, next: nil})
                |> Map.put(prev, p)
            end

          {acc, key, chapter_acc}
        end
      end)

    state =
      Enum.reduce(chapter_keys, pages, fn key, acc ->
        Map.put(acc, key, %{
          id: state[key],
          prev: nil,
          next: nil
        })
      end)

    state
  end

  def handle_continue(:initialize, _state) do
    state = refresh_indices()
    {:noreply, state}
  end

  def handle_cast(:rebuild, _state) do
    :logger.debug("Rebuilding chapter index cache")
    {:noreply, refresh_indices()}
  end

  def handle_call({:get_page_idx, ch_idx, pg_idx}, _, state) do
    {:reply, Map.get(state, "#{ch_idx}_#{pg_idx}"), state}
  end

  def handle_call({:get_ch_idx, ch_idx}, _, state) do
    {:reply, Map.get(state, "#{ch_idx}"), state}
  end
end
