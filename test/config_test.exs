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
        initial_delay_ms: 0,
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

  end

  describe "check configuration" do

    test "specified properties override defaults" do
      app = %Config{
        panic_guide_url: "urlx",
        business_impact: "bix",
        technical_summary: "tsx"
      }

      check = {
        %{
          id: "test-1-id",
          name: "test-1",
          description: "Test 1",
          panic_guide_url: "url1",
          business_impact: "bi1",
          technical_summary: "ts1",
          severity: 2
        },
        Fettle.AlwaysHealthyCheck,
        [opt: 1]
      }

      {spec, module, config} = Config.check_from_config(check, app)

      assert spec == %Fettle.Spec{
        id: "test-1-id",
        name: "test-1",
        description: "Test 1",
        panic_guide_url: "url1",
        business_impact: "bi1",
        technical_summary: "ts1",
        severity: 2
      }

      assert module == Fettle.AlwaysHealthyCheck
      assert config == [opt: 1]

    end

    test "uses defaults from top-level config" do
      app = %Config{
        panic_guide_url: "urlx",
        business_impact: "bix",
        technical_summary: "tsx"
      }

      check = {
        %{
          name: "test-1",
          panic_guide_url: "",
          business_impact: nil
        },
        Fettle.AlwaysHealthyCheck,
        [a: 1, b: 2]
      }

      {spec, module, check_opts} = Config.check_from_config(check, app)

      assert spec == %Fettle.Spec{
        id: "test-1",
        name: "test-1",
        description: "test-1",
        panic_guide_url: "urlx",
        business_impact: "bix",
        technical_summary: "tsx",
        severity: 1
      }

      assert module == Fettle.AlwaysHealthyCheck
      assert check_opts == [a: 1, b: 2]
    end

    test "check module options are optional" do
      check = {
        %{
          name: "test-1",
          panic_guide_url: "urlx",
          business_impact: "bix",
          technical_summary: "tsx"
        },
        Fettle.AlwaysHealthyCheck
      }

      {_spec, _module, config} = Config.check_from_config(check, %Config{})

      assert config == []
    end

    test "missing required properties raise error" do
      spec = %{
          name: "Name",
          panic_guide_url: "urlx",
          business_impact: "bix",
          technical_summary: "tsx"
      }

      # missing required field
      for field <- [:name, :panic_guide_url, :business_impact, :technical_summary] do
        assert_raise ArgumentError, ~r/#{field}/, fn ->
          {
            Map.delete(spec, field),
            Fettle.AlwaysHealthyCheck
          } |> Config.check_from_config(%Config{})
        end
      end

      # required field is nil
      for field <- [:name, :panic_guide_url, :business_impact, :technical_summary] do
        assert_raise ArgumentError, ~r/#{field}/, fn ->
          {
            Map.put(spec, field, nil),
            Fettle.AlwaysHealthyCheck
          } |> Config.check_from_config(%Config{})
        end
      end

      # required field is empty string
      for field <- [:name, :panic_guide_url, :business_impact, :technical_summary] do
        assert_raise ArgumentError, ~r/#{field}/, fn ->
          {
            Map.put(spec, field, ""),
            Fettle.AlwaysHealthyCheck
          } |> Config.check_from_config(%Config{})
        end
      end

    end
  end

end