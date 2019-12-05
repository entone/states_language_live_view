defmodule StatesLanguageLiveView.ExampleWorkflow do
  @moduledoc """
  This is our state machine implementation, it implements the callbacks from the StatesLanguage library. 
  The defstruct also allows us to use this module as the state machine data. The :parent key was populated in our LiveView view, 
  with the pid of the LiveView process. We use this key to send messages back to the LiveView.

  The @external_resource module attribute tells mix to watch the JSON file, 
  and recompile our module if the underlying JSON changes.
  """

  @external_resource "priv/state_machines/example_workflow.json"
  use StatesLanguage, data: "priv/state_machines/example_workflow.json"

  alias StatesLanguage, as: SL
  alias __MODULE__, as: Data

  require Logger

  defstruct [:account_lookup_type, :account_id, :account, :error, :parent]

  @doc """
  We're pattern matching on our Resource and the current State. This makes it possible to call the same Resource but behave differently based on the current state. 

  The ignored argument is the Parameters from our JSON state definition, 
  in this case we're not utlizing any of the JSONPath support, and only working with our data, 
  which you can see is always in a %StatesLanguage{} struct, with our inital data that we started our process with in the :data key. 

  You can see the HTML to be rendered in our template variable, and the event to send to our LiveView process. 
  This should correlate to the TransitionEvent in the JSON, or the default of :transition.

  We send an update message to our LiveView process, and it takes care of sending the update to our HTML page.

  We aren't going to transtition to the next state until the user clicks the button, 
  so we don't return any additional actions, and we haven't captured any data yet, so we just return the original data.

  The rest of the handle_resources behave in a similar way. 
  """
  @impl true
  def handle_resource("Welcome", _, "Welcome", %SL{data: %Data{parent: p}} = data) do
    template = """
    <h3>Welcome</h3>
    <button phx-click="transition">Get Started</button>
    """

    send(p, {:update, template})
    {:ok, data, []}
  end

  @impl true
  def handle_resource(
        "AccountLookupChoice",
        _,
        "AccountLookupChoice",
        %SL{data: %Data{parent: p}} = data
      ) do
    template = """
    <h3>How would you like to look up your account?</h3>
    <button phx-click="phone_lookup">Phone Number?</button>
    <button phx-click="account_id_lookup">Account ID</button>
    """

    send(p, {:update, template})
    {:ok, data, []}
  end

  @doc """
  In this state we've captured some data we want to persist for the rest of the states to utilize, 
  so we update our data before returning it.
  """
  @impl true
  def handle_resource(
        "PhoneNumberLookup",
        _,
        "PhoneNumberLookup",
        %SL{data: %Data{parent: p} = data} = sl
      ) do
    template = """
    <h3>Please provide your phone number</h3>
    <form phx-submit="set_value:account_id">
      <input type="text" name="account_id"/>
      <input type="submit" value="Find Account" />
    </form>
    """

    send(p, {:update, template})
    {:ok, %SL{sl | data: %Data{data | account_lookup_type: :phone}}, []}
  end

  @impl true
  def handle_resource(
        "AccountIDLookup",
        _,
        "AccountIDLookup",
        %SL{data: %Data{parent: p} = data} = sl
      ) do
    template = """
    <h3>Please provide your account number</h3>
    <form phx-submit="set_value:account_id">
      <input type="text" name="account_id"/>
      <input type="submit" value="Find Account" />
    </form>
    """

    send(p, {:update, template})
    {:ok, %SL{sl | data: %Data{data | account_lookup_type: :account}}, []}
  end

  @doc """
  In this state we are simulating reaching out to another API or a database. 
  In the JSON spec we've defined possible errors in our Catch attribute. 
  Depending on the result of the lookup, we send a successatom or one of 2 error atoms. 
  """
  @impl true
  def handle_resource(
        "DoLookup",
        _,
        "DoLookup",
        %SL{data: %Data{account_id: ai, account_lookup_type: t}} = sl
      ) do
    Logger.info("Looking up account type #{t} with id #{ai}")

    {data, action} =
      case do_lookup(ai, t) do
        {:success, account} ->
          {
            Map.put(sl.data, :account, account),
            {:next_event, :internal, :success}
          }

        {:error, error} ->
          {
            Map.put(sl.data, :error, error),
            {:next_event, :internal, error}
          }
      end

    {:ok, %SL{sl | data: data}, action}
  end

  @doc """
  This state can only be reached if we've had a successful account lookup, so we can confidently display our account information.
  """
  @impl true
  def handle_resource("ShowAccount", _, "ShowAccount", %SL{data: %Data{parent: p} = data} = sl) do
    template = """
    <h3>Your Account Information</h3>
    <dl>
      <dt>ID</dt>
      <dd>#{data.account.id}</dd>
      <dt>Address</dt>
      <dd>#{data.account.address}</dd>
      <dt>Account Type</dt>
      <dd>#{data.account.account_type}</dd>
      <dt>Amount Due</dt>
      <dd>#{data.account.amount_due}</dd>
      <dt>Due Date</dt>
      <dd>#{data.account.due_date}</dd>
      <dt>Lookup Type</dt>
      <dd>#{data.account.lookup_type}</dd>
    </dl>
    """

    send(p, {:update, template})
    {:ok, sl, []}
  end

  @doc """
  All errors end up in this state, so we display it, and allow the user to try another lookup.
  """
  @impl true
  def handle_resource("ShowError", _, "ShowError", %SL{data: %Data{parent: p, error: error}} = sl) do
    template = """
    <h3>Error</h3>
    <h4>#{error}</h4>
    <button phx-click="ok">Try Again</button>
    """

    send(p, {:update, template})
    {:ok, sl, []}
  end

  @impl true
  def handle_resource(resource, _, state, data) do
    Logger.warn("Unhandled Resource #{resource} in state #{state}")
    {:ok, data, []}
  end

  @doc """
  The handle_call callback is called from our LiveView view, when setting the account id, 
  the key name is passed in as part of the event and converted to an atom here.

  We reply to the call with :ok, but also move onto the next state, 
  as we've captured our account id for lookup now.
  """
  @impl true
  def handle_call({:set_value, key, value}, from, _state, sl) do
    data = Map.put(sl.data, String.to_existing_atom(key), value)
    {:ok, %SL{sl | data: data}, [{:reply, from, :ok}, {:next_event, :internal, :do_lookup}]}
  end

  defp do_lookup("1", _) do
    {:error, :account_not_found}
  end

  defp do_lookup("2", _) do
    {:error, :internal_error}
  end

  defp do_lookup(id, type) do
    {:success,
     %{
       id: id,
       address: "555 Main St, Pleasantville, IL 61111",
       amount_due: "$198.43",
       account_type: "broadband",
       lookup_type: type,
       due_date: "2019-11-18"
     }}
  end
end
