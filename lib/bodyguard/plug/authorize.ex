defmodule Bodyguard.Plug.Authorize do
  @behaviour Plug
  
  @moduledoc """
  Perform authorization in a Plug pipeline.

  ## Options
  
  * `policy` *required* - the policy (or context) module
  * `action` *required* - the action to authorize
  * `user` - a 1-arity function which accepts the connection and returns a
    user. If omitted, detaults `user` to `nil`
  * `params` - params to pass to the authorization callbacks
  * `fallback` - a fallback controller or plug to handle authorization
    failure. If specified, the plug is called and then the pipeline is
    `halt`ed. If not specified, then `Bodyguard.NotAuthorizedError` raises
    directly to the router.

  ## Examples

      # Raise on failure
      plug Bodyguard.Plug.Authorize, policy: MyApp.Blog, action: :update_posts, 
        user: &get_current_user/1 

      # Fallback on failure
      plug Bodyguard.Plug.Authorize, policy: MyApp.Blog, action: :update_posts, 
        user: &get_current_user/1, fallback: MyApp.FallbackController
  """

  def init(opts \\ []) do
    policy    = Keyword.get(opts, :policy)
    action    = Keyword.get(opts, :action)
    user      = Keyword.get(opts, :user)
    params    = Keyword.get(opts, :params, [])
    fallback  = Keyword.get(opts, :fallback)

    if is_nil(policy), do: raise ArgumentError, "#{inspect(__MODULE__)} :policy option required"
    if is_nil(action), do: raise ArgumentError, "#{inspect(__MODULE__)} :action option required"
    unless is_nil(user) or is_function(user, 1),
      do: raise ArgumentError, "#{inspect(__MODULE__)} :user options must be nil or a 1-arity function that accepts conn and returns a user"
    unless is_nil(fallback) or is_atom(fallback),
      do: raise ArgumentError, "#{inspect(__MODULE__)} :fallback option must be a plug module"

    %{
      policy:   policy,
      action:   action,
      user:     user,
      params:   params,
      fallback: fallback,
    }
  end

  def call(conn, %{fallback: nil} = opts) do
    Bodyguard.permit!(opts.policy, opts.action, opts.user, opts.params)
    conn
  end
  def call(conn, opts) do
    case Bodyguard.permit(opts.policy, opts.action, opts.user, opts.params) do
      :ok -> conn
      error -> 
        conn
        |> opts.fallback.call(error)
        |> Plug.Conn.halt()
    end
  end
end