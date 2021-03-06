defmodule Rig.EventFilter.ServerTest do
  @moduledoc false
  use ExUnit.Case, async: false
  doctest Rig.EventFilter.Server

  alias CloudEvent
  alias Rig.EventFilter
  alias Rig.EventFilter.Server
  alias Rig.Subscription

  test "subscribe & receive an event" do
    event_type = "test.event"
    field_config = %{}
    subscription = Subscription.new(%{event_type: event_type})

    event =
      CloudEvent.new!(%{
        "cloudEventsVersion" => "0.1",
        "eventType" => event_type,
        "source" => "test"
      })

    opts = [debug?: true, subscription_ttl_s: 0]
    {:ok, filter_pid} = Server.start_link(event_type, field_config, opts)

    EventFilter.refresh_subscriptions([subscription], [])
    EventFilter.forward_event(event)
    EventFilter.forward_event(event)

    assert_receive {:cloud_event, ^event}
    assert_receive {:cloud_event, ^event}

    # No longer receive an event for timed-out subscriptions after :cleanup:
    simulate_cleanup(filter_pid)
    EventFilter.forward_event(event)
    refute_receive {:cloud_event, ^event}

    :ok = GenServer.stop(filter_pid)
  end

  defp simulate_cleanup(pid) do
    pid
    |> :sys.get_state()
    |> Server.remove_expired_records()
  end

  test "receive only events that satisfy constraints" do
    event_type = "person.create"

    field_config = %{
      "age" => %{
        "stable_field_index" => 1,
        "event" => %{"json_pointer" => "/data/age"}
      },
      "name" => %{
        "stable_field_index" => 0,
        "event" => %{"json_pointer" => "/data/name"}
      }
    }

    name_is_joe = %{"name" => "joe"}
    age_is_30 = %{"age" => 30}

    joe_subscription = Subscription.new(%{event_type: event_type, constraints: [name_is_joe]})

    joe_and_30_subscription =
      Subscription.new(%{event_type: event_type, constraints: [Map.merge(name_is_joe, age_is_30)]})

    base_event =
      CloudEvent.new!(%{
        "cloudEventsVersion" => "0.1",
        "eventType" => event_type,
        "source" => "test"
      })

    joe_20_event = CloudEvent.with_data(base_event, %{"name" => "joe", "age" => 20, "x" => "x"})
    joe_30_event = CloudEvent.with_data(base_event, %{"name" => "joe", "age" => 30, "x" => "x"})
    bob_30_event = CloudEvent.with_data(base_event, %{"name" => "bob", "age" => 30, "x" => "x"})

    joe_noage_event =
      CloudEvent.with_data(base_event, %{"name" => "joe", "age" => nil, "x" => "x"})

    specs = [
      {joe_subscription, joe_20_event, :match},
      {joe_subscription, joe_30_event, :match},
      {joe_subscription, joe_noage_event, :match},
      {joe_subscription, bob_30_event, :no_match},
      {joe_and_30_subscription, joe_20_event, :no_match},
      {joe_and_30_subscription, joe_30_event, :match},
      {joe_and_30_subscription, joe_noage_event, :no_match},
      {joe_and_30_subscription, bob_30_event, :no_match}
    ]

    for {subscription, event, match_expectation} <- specs do
      {:ok, filter_pid} = Server.start_link(event_type, field_config)
      EventFilter.refresh_subscriptions([subscription], [])
      EventFilter.forward_event(event)

      case match_expectation do
        :match -> assert_receive {:cloud_event, ^event}
        :no_match -> refute_receive {:cloud_event, ^event}
      end

      :ok = GenServer.stop(filter_pid)
    end
  end
end
