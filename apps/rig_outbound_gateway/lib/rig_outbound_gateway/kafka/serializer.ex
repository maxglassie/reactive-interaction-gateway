defmodule RigOutboundGateway.Kafka.Serializer do
  @moduledoc """
  TODO
  """

  alias RigOutboundGateway.Kafka.Avro

  @spec decode_body(String.t(), String.t(), String.t()) :: map()
  def decode_body(body, nil, _schema), do: body

  def decode_body(body, "avro", schema) do
    schema
    |> Avro.parse_schema
    |> Avro.decode(body)
  end
end
