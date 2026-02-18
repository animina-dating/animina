defmodule Animina.AI.ClientRoundRobinTest do
  use ExUnit.Case, async: true

  alias Animina.AI.Client

  describe "rotate_instances/2" do
    test "rotates same-priority instances by counter" do
      instances = [
        %{url: "gpu1", timeout: 120_000, priority: 1},
        %{url: "gpu2", timeout: 120_000, priority: 1}
      ]

      # counter=0 → offset 0 → [gpu1, gpu2]
      assert [%{url: "gpu1"}, %{url: "gpu2"}] = Client.rotate_instances(instances, 0)

      # counter=1 → offset 1 → [gpu2, gpu1]
      assert [%{url: "gpu2"}, %{url: "gpu1"}] = Client.rotate_instances(instances, 1)

      # counter=2 → offset 0 → [gpu1, gpu2]
      assert [%{url: "gpu1"}, %{url: "gpu2"}] = Client.rotate_instances(instances, 2)

      # counter=3 → offset 1 → [gpu2, gpu1]
      assert [%{url: "gpu2"}, %{url: "gpu1"}] = Client.rotate_instances(instances, 3)
    end

    test "lower-priority instances always come after higher-priority" do
      instances = [
        %{url: "gpu1", timeout: 120_000, priority: 1},
        %{url: "gpu2", timeout: 120_000, priority: 1},
        %{url: "cpu", timeout: 120_000, priority: 2}
      ]

      result = Client.rotate_instances(instances, 1)

      # GPU group rotated, CPU always last
      assert [%{url: "gpu2"}, %{url: "gpu1"}, %{url: "cpu"}] = result
    end

    test "single-instance group is unaffected by rotation" do
      instances = [
        %{url: "only-one", timeout: 120_000, priority: 1}
      ]

      assert [%{url: "only-one"}] = Client.rotate_instances(instances, 0)
      assert [%{url: "only-one"}] = Client.rotate_instances(instances, 1)
      assert [%{url: "only-one"}] = Client.rotate_instances(instances, 99)
    end

    test "three instances in same priority group rotate correctly" do
      instances = [
        %{url: "a", timeout: 120_000, priority: 1},
        %{url: "b", timeout: 120_000, priority: 1},
        %{url: "c", timeout: 120_000, priority: 1}
      ]

      # counter=0 → offset 0 → [a, b, c]
      assert [%{url: "a"}, %{url: "b"}, %{url: "c"}] = Client.rotate_instances(instances, 0)

      # counter=1 → offset 1 → [b, c, a]
      assert [%{url: "b"}, %{url: "c"}, %{url: "a"}] = Client.rotate_instances(instances, 1)

      # counter=2 → offset 2 → [c, a, b]
      assert [%{url: "c"}, %{url: "a"}, %{url: "b"}] = Client.rotate_instances(instances, 2)

      # counter=3 → offset 0 → [a, b, c]
      assert [%{url: "a"}, %{url: "b"}, %{url: "c"}] = Client.rotate_instances(instances, 3)
    end

    test "multiple priority groups each rotate independently" do
      instances = [
        %{url: "gpu1", timeout: 120_000, priority: 1},
        %{url: "gpu2", timeout: 120_000, priority: 1},
        %{url: "cpu1", timeout: 120_000, priority: 2},
        %{url: "cpu2", timeout: 120_000, priority: 2}
      ]

      # counter=1 → gpu group offset 1, cpu group offset 1
      result = Client.rotate_instances(instances, 1)

      assert [%{url: "gpu2"}, %{url: "gpu1"}, %{url: "cpu2"}, %{url: "cpu1"}] = result
    end

    test "empty list returns empty list" do
      assert [] = Client.rotate_instances([], 0)
      assert [] = Client.rotate_instances([], 42)
    end
  end
end
