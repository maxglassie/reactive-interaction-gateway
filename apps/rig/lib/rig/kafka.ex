defmodule Rig.Kafka do
  @moduledoc """
  Producing messages to Kafka topics.

  """
  use Rig.Config, [:enabled?, :brod_client_id]
  alias RigOutboundGateway.Kafka.Avro
  alias RigOutboundGateway.Kafka.Serializer

  @type produce_fn ::
          (:brod.client(),
           :brod.topic(),
           :brod.partition()
           | :brod.partition_fun(),
           :brod.key(),
           :brod.value() ->
             :ok | {:error, any()})
  @spec produce(:brod.topic(), String.t(), :brod.key(), plaintext :: :brod.value(), produce_fn()) ::
          :ok | false
  def produce(topic, schema, key, plaintext, produce_fn \\ &:brod.produce_sync/5) do
    conf = config()

    if conf.enabled? do
      encoded_body = Serializer.encode_body(plaintext, conf.serializer, schema)
      do_produce(topic, key, encoded_body, produce_fn)
    end
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

  defp compute_kafka_partition(_topic, n_partitions, key, _value) do
    partition =
      key
      |> Murmur.hash_x86_32()
      |> abs
      |> rem(n_partitions)

    {:ok, partition}
  end
end
