defmodule KC.Application do
  @moduledoc false
  use Application

  @key_base_file "priv/key_base.bin"
  @signing_salt_file "priv/signing_salt.bin"
  @encryption_salt_file "priv/encryption_salt.bin"

  defp check_key_file(name, path, len) do
    if not File.exists?(path) do
      :logger.info("No #{name} found -- generating")
      bytes = :crypto.strong_rand_bytes(len)
      File.write!(path, bytes)
    end
  end

  def start(_type, _args) do
    check_key_file("secret key base", @key_base_file, 64)
    check_key_file("signing salt", @signing_salt_file, 16)
    check_key_file("encryption salt", @encryption_salt_file, 16)

    secret_key_base = File.read!(@key_base_file)
    signing_salt = File.read!(@signing_salt_file)
    encryption_salt = File.read!(@encryption_salt_file)

    Application.put_env(:kc_core, KC.API,
      secret_key_base: secret_key_base,
      signing_salt: signing_salt,
      encryption_salt: encryption_salt
    )

    children = [
      KC.Repo,
      KC.API.IndexCache,
      {Bandit, plug: KC.API.Router, port: 7800}
    ]

    opts = [
      strategy: :one_for_one,
      name: KC.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end
