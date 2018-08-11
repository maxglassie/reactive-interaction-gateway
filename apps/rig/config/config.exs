use Mix.Config

config :rig, Rig.Kafka,
  # must match rig_outbound_gateway's config:
  brod_client_id: :rig_brod_client,
  enabled?: {:system, :boolean, "KAFKA_ENABLED", false},
  serializer: {:system, :string, "KAFKA_SERIALIZER", nil}

config :porcelain, driver: Porcelain.Driver.Basic

import_config "#{Mix.env}.exs"
