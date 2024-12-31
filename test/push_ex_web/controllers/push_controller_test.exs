defmodule PushExWeb.PushControllerTest do
  use PushExWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  test "a single channel can be pushed to", %{conn: conn, test: channel} do
    PushEx.Test.MockController.setup_config(:logging)
    PushEx.Test.MockInstrumenter.setup_config()
    channel = to_string(channel)
    params = %{"channel" => channel, "data" => "d", "event" => "e"}

    log =
      capture_log(fn ->
        assert conn
               |> post("/api/push", params)
               |> json_response(200) == %{"channel" => [channel], "data" => "d", "event" => "e"}

        Process.sleep(20)
      end)

    assert %{
             api_processed: [[:ctx]],
             api_requested: [[:ctx]],
             delivered: [],
             requested: [[%PushEx.Push{channel: ^channel, data: "d", event: "e", unix_ms: _}, :ctx]]
           } = PushEx.Test.MockInstrumenter.state()

    assert log =~ "LoggingController auth/2 " <> inspect({"conn", params})
    assert log =~ "Push.ItemServer no_listeners channel=#{channel}"
  end

  test "multiple channels can be pushed to, without duplicates", %{conn: conn, test: channel} do
    PushEx.Test.MockController.setup_config(:logging)
    PushEx.Test.MockInstrumenter.setup_config()
    channels = [to_string(channel), to_string(channel) <> "2"]
    params = %{"channel" => [to_string(channel) | channels], "data" => "d", "event" => "e"}

    log =
      capture_log(fn ->
        assert conn
               |> post("/api/push", params)
               |> json_response(200) == %{"channel" => channels, "data" => "d", "event" => "e"}

        Process.sleep(20)
      end)

    ch0 = Enum.at(channels, 0)
    ch1 = Enum.at(channels, 1)

    assert %{
             api_processed: api_processed,
             api_requested: api_requested,
             delivered: delivered,
             requested: [
               [%PushEx.Push{channel: ^ch1, data: "d", event: "e", unix_ms: _}, :ctx],
               [%PushEx.Push{channel: ^ch0, data: "d", event: "e", unix_ms: _}, :ctx]
             ]
           } = PushEx.Test.MockInstrumenter.state()

    assert api_processed == [[:ctx]]
    assert api_requested == [[:ctx]]
    assert delivered == []

    assert log =~ "LoggingController auth/2 " <> inspect({"conn", params})
    assert log =~ "Push.ItemServer no_listeners channel=#{Enum.at(channels, 0)}"
    assert log =~ "Push.ItemServer no_listeners channel=#{Enum.at(channels, 1)}"
  end

  ["channel", "data", "event"]
  |> Enum.map(fn field ->
    test "#{field} is a required param", %{conn: conn, test: channel} do
      PushEx.Test.MockController.setup_config(:logging)
      params = Map.delete(%{"channel" => channel, "data" => "d", "event" => "e"}, unquote(field))

      log =
        capture_log(fn ->
          assert conn
                 |> post("/api/push", params)
                 |> json_response(422) == %{"error" => "Invalid push arguments: channel, data, event are required."}

          Process.sleep(20)
        end)

      refute log =~ "Push.ItemServer"
    end
  end)

  describe "with_auth" do
    test ":error returns a 403", %{conn: conn, test: channel} do
      PushEx.Test.MockController.setup_config(:error)
      params = %{"channel" => channel, "data" => "d", "event" => "e"}

      log =
        capture_log(fn ->
          assert conn
                 |> post("/api/push", params)
                 |> json_response(403) == %{"error" => "Access forbidden"}

          Process.sleep(20)
        end)

      refute log =~ "Push.ItemServer"
    end

    test "{:error, conn} returns the conn directly", %{conn: conn, test: channel} do
      PushEx.Test.MockController.setup_config(:specific_error)
      params = %{"channel" => channel, "data" => "d", "event" => "e"}

      log =
        capture_log(fn ->
          assert conn
                 |> post("/api/push", params)
                 |> response(400) == "resp"

          Process.sleep(20)
        end)

      refute log =~ "Push.ItemServer"
    end

    test "{:ok, conn, params} calls with the modified params/conn", %{conn: conn, test: channel} do
      PushEx.Test.MockController.setup_config(:specific_ok)
      params = %{"channel" => channel, "data" => "d", "event" => "e"}

      log =
        capture_log(fn ->
          assert conn
                 |> post("/api/push", params)
                 |> json_response(202) == %{"channel" => ["modified"], "data" => "d", "event" => "e"}

          Process.sleep(20)
        end)

      assert log =~ "Push.ItemServer no_listeners channel=modified event=e"
    end
  end

  describe "not_implemented" do
    test "an error is raised", %{conn: conn, test: channel} do
      PushEx.Test.MockController.setup_config(:not_implemented)
      params = %{"channel" => channel, "data" => "d", "event" => "e"}

      assert_raise(RuntimeError, "PushExWeb.PushController is not implemented (from your app config)", fn ->
        post(conn, "/api/push", params)
      end)
    end
  end

  describe "Config.close_connections?" do
    test "Connection: close header is added to the response", %{conn: conn, test: channel} do
      PushEx.Test.MockController.setup_config(:logging)
      PushEx.Test.MockInstrumenter.setup_config()
      channel = to_string(channel)
      params = %{"channel" => channel, "data" => "d", "event" => "e"}

      PushExWeb.Config.close_connections!(true)

      capture_log(fn ->
        res_conn = post(conn, "/api/push", params)
        assert json_response(res_conn, 200) == %{"channel" => [channel], "data" => "d", "event" => "e"}
        assert Enum.find(res_conn.resp_headers, &(&1 == {"connection", "close"})) == {"connection", "close"}
      end)
    end

    test "Connection: close header is not added to the response when not set", %{conn: conn, test: channel} do
      PushEx.Test.MockController.setup_config(:logging)
      PushEx.Test.MockInstrumenter.setup_config()
      channel = to_string(channel)
      params = %{"channel" => channel, "data" => "d", "event" => "e"}

      PushExWeb.Config.close_connections!(false)

      capture_log(fn ->
        res_conn = post(conn, "/api/push", params)
        assert json_response(res_conn, 200) == %{"channel" => [channel], "data" => "d", "event" => "e"}
        assert Enum.find(res_conn.resp_headers, &(&1 == {"connection", "close"})) == nil
      end)
    end
  end
end
