defmodule TestFrontendSocket do
  def socket_connect(params, socket) do
    IO.inspect {"my socket_connect invoked with", params, socket}

    socket =
      Phoenix.Socket.assign(socket, :secret_id, :rand.uniform(999999))

    {:ok, socket}
  end

  def socket_id(%{assigns: %{secret_id: id}}) do
    "secret:#{id}"
  end

  def channel_join(channel, params, socket) do
    IO.inspect {"my channel_join invoked with", channel, params, socket}
    {:ok, socket}
  end
end
