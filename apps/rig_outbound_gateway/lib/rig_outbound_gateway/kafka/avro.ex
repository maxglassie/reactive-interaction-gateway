defmodule RigOutboundGateway.Kafka.Avro do
  @moduledoc """
  TODO
  """
  require Logger
  use Memoize
  use Rig.Config, [:schema_registry_host]

  @spec parse_schema(String.t()) :: map()
  def parse_schema(subject) do
    {:ok, %{"schema" => raw_schema}} = get(subject)
    schema = :avro.decode_schema(raw_schema)
    Logger.debug("Using Avro schema=#{subject} with definition=#{inspect schema}")
    schema
  end

  @spec decode(String.t(), any()) :: String.t()
  def decode(schema, data) do
    decoded_data =
      data
      |> :avro_binary_decoder.decode(schema, fn(schema_subject) -> raise("Incorrect Avro schema=#{schema_subject}") end)
      |> :jsone.encode

    Logger.debug("Decoded Avro message=#{inspect decoded_data}")
    decoded_data
  end

  @spec encode(String.t(), any()) :: list()
  def encode(schema, data) do
    parsed_schema = parse_schema(schema)
    :avro_binary_encoder.encode(fn(_) -> parsed_schema end, schema, deep_map_to_list(data))
  end

  @spec deep_map_to_list(any()) :: list()
  defp deep_map_to_list(m) do
    if is_map(m) do
      Map.to_list(m)
      |> Enum.map(fn({key, value}) -> {key, deep_map_to_list(value)} end)
    else
      m
    end
  end

  @spec get(String.t()) :: map()
  defmemo get(subject) do
    config().schema_registry_host
    |> Schemex.latest(subject)
  end

end
