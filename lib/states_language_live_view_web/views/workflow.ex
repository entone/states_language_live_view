defmodule StatesLanguageLiveViewWeb.Workflow do
  @moduledoc """
  LiveView view to start and example workflow
  """
  use Phoenix.LiveView
  use Phoenix.HTML
  require Logger
  alias StatesLanguageLiveView.ExampleWorkflow

  @initial_data "Loading..."

  def render(assigns) do
    ~L"""
    <div><%= raw(@data) %></div>
    """
  end

  @doc """
  Once our LiveView socket is connected, we'll start our ExampleWorkflow, our state machine implementation.

  We pass a struct of type ExampleWorkflow as the data for our state machine. 
  This will get populated with data as we move through our state machine.

  We also capture the pid of the workflow, and set some initial data while we wait for everything to get setup.
  """
  def mount(%{}, socket) do
    Logger.info("Mounting")

    {_, pid} =
      if connected?(socket) do
        Logger.info("Starting Example Workflow...")
        ExampleWorkflow.start_link(%ExampleWorkflow{parent: self()})
        Logger.info("Example Workflow Started")
      else
        {:noop, nil}
      end

    {:ok, assign(socket, data: @initial_data, workflow: pid)}
  end

  @doc """
  When inputting a phone number or account id in our HTML form, and pressing the button, 
  this callback pattern matches on our event type, and uses the remainder of the binary data to indicate which form name to get our data from. 
  In this case it also happens to match the key we're going to store the value in, in our state machine data.
  """
  def handle_event(<<"set_value:", key::binary()>>, values, socket) do
    Logger.info("setting values for: #{key} #{inspect(values)}")
    :ok = ExampleWorkflow.call(socket.assigns.workflow, {:set_value, key, Map.get(values, key)})
    {:noreply, socket}
  end

  @doc """
  This handles all other events from our HTML forms from our button presses.
  """
  def handle_event(event, _, socket) do
    event = String.to_existing_atom(event)
    Logger.info("Sending Event #{inspect(event)} to #{inspect(socket.assigns.workflow)}")
    send(socket.assigns.workflow, event)
    {:noreply, socket}
  end

  @doc """
  This is a GenServer callback that matches on messages sent from our state machine. I
  t updates our data attribute on our socket, which triggers LiveView to push a message down the WebSocket, and re-render our form.
  """
  def handle_info({:update, data}, socket) do
    Logger.info("Updating UI")
    {:noreply, assign(socket, data: data)}
  end
end
