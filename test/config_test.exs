defmodule ConfigTest do
  use ExUnit.Case

  alias Fettle.Config

  describe "top-level config" do
    test "defaults unspecified properties" do
      app = %{
        system_code: "system-code"
      }

      config = Config.to_app_config(app)

      assert config == %Config{
               system_code: "system-code",
               name: "system-code",
               description: "system-code",
               schema: Fettle.Schema.FTHealthCheckV1,
               period_ms: 30000,
               initial_delay_ms: 500,
               timeout_ms: 5000
             }
    end

    test "missing required properties raises error" do
      app = %{
        period_ms: 30000
      }

      assert_raise ArgumentError, fn -> Config.to_app_config(app) end
    end

    test "specified properties override defaults" do
      app = %{
        system_code: "system-code",
        name: "a name",
        description: "a description",
        schema: Fettle.Schema.V2,
        period_ms: 60000,
        initial_delay_ms: 1000,
        timeout_ms: 10000,
        panic_guide_url: "http://ft.com",
        technical_summary: "tech summary",
        business_impact: "biz impact"
      }

      config = Config.to_app_config(app)

      assert config == %Config{
               system_code: "system-code",
               name: "a name",
               description: "a description",
               schema: Fettle.Schema.V2,
               period_ms: 60000,
               initial_delay_ms: 1000,
               timeout_ms: 10000,
               panic_guide_url: "http://ft.com",
               technical_summary: "tech summary",
               business_impact: "biz impact"
             }
    end

    test "integer properties can be passed as strings" do
      app = %{
        system_code: "system-code",
        period_ms: "10",
        initial_delay_ms: "20",
        timeout_ms: "30"
      }

      config = Config.to_app_config(app)

      assert %{period_ms: 10, initial_delay_ms: 20, timeout_ms: 30} = config
    end
  end

  describe "check configuration" do
    test "specified properties override defaults" do
      config = %Config{
        panic_guide_url: "urlx",
        business_impact: "bix",
        technical_summary: "tsx",
        period_ms: 10_000,
        initial_delay_ms: 15_000,
        timeout_ms: 5_000
      }

      check = %{
        id: "test-1-id",
        name: "test-1",
        description: "Test 1",
        panic_guide_url: "url1",
        business_impact: "bi1",
        technical_summary: "ts1",
        severity: 2,
        period_ms: 11_000,
        initial_delay_ms: 8_000,
        timeout_ms: 20_000,
        checker: Fettle.AlwaysHealthyCheck,
        args: [opt: 1]
      }

      {spec, module, args} = Config.check_from_config(check, config)

      assert spec == %Fettle.Spec{
               id: "test-1-id",
               name: "test-1",
               description: "Test 1",
               panic_guide_url: "url1",
               business_impact: "bi1",
               technical_summary: "ts1",
               severity: 2,
               period_ms: 11_000,
               initial_delay_ms: 8_000,
               timeout_ms: 20_000
             }

      assert module == Fettle.AlwaysHealthyCheck
      assert args == [opt: 1]
    end

    test "uses defaults from top-level config" do
      config = %Config{
        panic_guide_url: "urlx",
        business_impact: "bix",
        technical_summary: "tsx",
        initial_delay_ms: 1000,
        timeout_ms: 2000,
        period_ms: 3000
      }

      check = %{
        name: "test-1",
        panic_guide_url: "",
        business_impact: nil,
        checker: Fettle.AlwaysHealthyCheck,
        args: [a: 1]
      }

      {spec, module, args} = Config.check_from_config(check, config)

      assert spec == %Fettle.Spec{
               id: "test-1",
               name: "test-1",
               description: "test-1",
               panic_guide_url: "urlx",
               business_impact: "bix",
               technical_summary: "tsx",
               severity: 1,
               initial_delay_ms: 1000,
               timeout_ms: 2000,
               period_ms: 3000
             }

      assert module == Fettle.AlwaysHealthyCheck
      assert args == [a: 1]
    end

    test "check module args are optional" do
      config = config()

      check = %{
        name: "test-1",
        checker: Fettle.AlwaysHealthyCheck
      }

      {_spec, _module, args} = Config.check_from_config(check, config)

      assert args == []
    end

    test "missing required properties raise error" do
      minimal_config = %Config{initial_delay_ms: 1, period_ms: 1, timeout_ms: 1}

      spec = %{
        name: "Name",
        panic_guide_url: "urlx",
        business_impact: "bix",
        technical_summary: "tsx",
        checker: Fettle.AlwaysHealthyCheck
      }

      # missing required field
      for field <- [:name, :panic_guide_url, :business_impact, :technical_summary, :checker] do
        assert_raise ArgumentError, ~r/#{field}/, fn ->
          Map.delete(spec, field)
          |> Config.check_from_config(minimal_config)
        end
      end

      # required field is nil
      for field <- [:name, :panic_guide_url, :business_impact, :technical_summary, :checker] do
        assert_raise ArgumentError, ~r/#{field}/, fn ->
          Map.put(spec, field, nil)
          |> Config.check_from_config(minimal_config)
        end
      end

      # required field is empty string
      for field <- [:name, :panic_guide_url, :business_impact, :technical_summary] do
        assert_raise ArgumentError, ~r/#{field}/, fn ->
          Map.put(spec, field, "")
          |> Config.check_from_config(minimal_config)
        end
      end
    end

    test "illegal property values raise error" do
      minimal_config = %Config{initial_delay_ms: 1, period_ms: 1, timeout_ms: 1}

      spec = %{
        name: "Name",
        panic_guide_url: "urlx",
        business_impact: "bix",
        technical_summary: "tsx",
        checker: Fettle.AlwaysHealthyCheck
      }

      # negative values
      for field <- [:initial_delay_ms, :period_ms, :timeout_ms] do
        assert_raise ArgumentError, ~r/#{field}/, fn ->
          Map.put(spec, field, -1)
          |> Config.check_from_config(minimal_config)
        end
      end

      # out of range
      assert_raise ArgumentError, ~r/severity/, fn ->
        Map.put(spec, :severity, 9)
        |> Config.check_from_config(minimal_config)
      end
    end
  end

  def config() do
    %Config{
      panic_guide_url: "pgu",
      business_impact: "bi",
      technical_summary: "ts",
      initial_delay_ms: 1000,
      timeout_ms: 2000,
      period_ms: 3000
    }
  end
end
