defmodule Riftboard.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Riftboard.Repo

  alias Riftboard.Accounts.{User, UserToken}

  @guest_colors ~w(#ef4444 #f97316 #eab308 #22c55e #06b6d4 #3b82f6 #8b5cf6 #ec4899)
  @guest_adjectives ~w(Swift Calm Bright Bold Quiet Clever Happy Lucky)
  @guest_animals ~w(Fox Owl Otter Wolf Hawk Bear Lynx Deer)

  @doc """
  Generates a random display name + color pair, used for both guest accounts
  and to fill in a real user's profile if they didn't set one.
  """
  def random_guest_identity do
    %{
      name: "#{Enum.random(@guest_adjectives)} #{Enum.random(@guest_animals)}",
      color: Enum.random(@guest_colors)
    }
  end

  ## Database getters

  @doc """
  Gets a user by username and password.

  ## Examples

      iex> get_user_by_username_and_password("alice", "correct_password")
      %User{}

      iex> get_user_by_username_and_password("alice", "invalid_password")
      nil

  """
  def get_user_by_username_and_password(username, password)
      when is_binary(username) and is_binary(password) do
    user = Repo.get_by(User, username: username)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_username: false)
  end

  @doc """
  Registers a guest user with a random display name and no real credentials —
  used by the "Continue as Guest" button.
  """
  def register_guest_user do
    register_user(%{
      "username" => "guest-#{Ecto.UUID.generate()}",
      "password" => :crypto.strong_rand_bytes(24) |> Base.url_encode64(),
      "is_guest" => true
    })
  end

  @doc """
  Registers a user under a chosen username + password — used by the
  "Create account" form on the login screen.
  """
  def register_named_user(username, password) do
    register_user(%{
      "username" => username,
      "password" => password,
      "display_name" => username,
      "is_guest" => false
    })
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end
end
