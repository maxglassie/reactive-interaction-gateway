defmodule Rig.Kafka do
  @moduledoc """
  Producing messages to Kafka topics.

  """
  use Rig.Config, [:enabled?, :brod_client_id]
  alias RigOutboundGateway.Kafka.Avro

  @spec produce(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          fun()
        ) :: :ok
  def produce(topic, schema, key, plaintext, produce_fn \\ &:brod.produce_sync/5) do
    conf = config()
    if conf.enabled? do
      encoded_body = encode_body(plaintext, conf.serializer, schema)
      do_produce(topic, key, encoded_body, produce_fn)
    end
  end

  @spec encode_body(String.t(), String.t(), String.t()) :: String.t()
  defp encode_body(body, nil, _schema), do: body

  defp encode_body(body, "avro", schema) do
    schema
    |> Avro.parse_schema
    |> Avro.encode(body)
  end

  @spec do_produce(String.t(), String.t(), String.t(), fun()) :: :ok
  defp do_produce(topic, key, plaintext, produce_fn) do
    conf = config()

    :ok =
      produce_fn.(
        conf.brod_client_id,
        topic,
        _partition = &compute_kafka_partition/4,
        key,
        _value = plaintext
      )
  end

  @spec compute_kafka_partition(String.t(), String.t(), String.t(), String.t()) :: {:ok, non_neg_integer()}
  defp compute_kafka_partition(_topic, n_partitions, key, _value) do
    partition =
      key
      |> Murmur.hash_x86_32()
      |> abs
      |> rem(n_partitions)

    {:ok, partition}
  end
end
