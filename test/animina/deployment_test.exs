defmodule Animina.DeploymentTest do
  use ExUnit.Case, async: true

  alias Animina.Deployment

  describe "notify_deploying/1" do
    test "broadcasts {:deploying, version} on the deployment topic" do
      Phoenix.PubSub.subscribe(Animina.PubSub, Deployment.topic())

      assert :ok = Deployment.notify_deploying("2.2.3")
      assert_receive {:deploying, "2.2.3"}
    end

    test "broadcasts {:deploying, nil} when no version is given" do
      Phoenix.PubSub.subscribe(Animina.PubSub, Deployment.topic())

      assert :ok = Deployment.notify_deploying()
      assert_receive {:deploying, nil}
    end
  end

  describe "topic/0" do
    test "returns a string topic" do
      assert is_binary(Deployment.topic())
    end
  end
end
