import Config

config :ex_aws, :http_client, ExAws.Request.Req

config :ex_aws, :s3,
  scheme: "https://",
  host: System.fetch_env("KC_S3_HOST"),
  access_key_id: System.fetch_env("KC_S3_ACCESS_KEY"),
  secret_access_key: System.fetch_env("KC_S3_SECRET_KEY")

config :kc_core, KC.Repo,
  database: "kemoner_club",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :kc_core, S3, bucket: "kemoner-club"

config :kc_core,
  ecto_repos: [KC.Repo]
