defmodule RiftboardWeb.UserLoginLive do
  use RiftboardWeb, :live_view

  alias Riftboard.Accounts
  alias Riftboard.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Welcome to Riftboard</.header>

      <div class="relative mt-8 flex rounded-lg bg-zinc-100 p-1 text-sm font-semibold">
        <span
          class={[
            "absolute inset-y-1 left-1 w-1/2 rounded-md bg-white shadow transition-transform duration-200 ease-out",
            @mode == :register && "translate-x-full"
          ]}
        />
        <button
          type="button"
          phx-click="switch_mode"
          phx-value-mode="login"
          class={[
            "relative z-10 flex-1 rounded-md py-1.5 transition-colors",
            @mode == :login && "text-zinc-900",
            @mode == :register && "text-zinc-400 hover:text-zinc-600"
          ]}
        >
          Log in
        </button>
        <button
          type="button"
          phx-click="switch_mode"
          phx-value-mode="register"
          class={[
            "relative z-10 flex-1 rounded-md py-1.5 transition-colors",
            @mode == :register && "text-zinc-900",
            @mode == :login && "text-zinc-400 hover:text-zinc-600"
          ]}
        >
          Create account
        </button>
      </div>

      <div :if={@mode == :login} class="mt-8">
        <.simple_form
          for={@login_form}
          id="login_form"
          action={~p"/users/log_in"}
          phx-update="ignore"
        >
          <.input
            field={@login_form[:username]}
            id="login_username"
            type="text"
            label="Username"
            required
          />
          <.input
            field={@login_form[:password]}
            id="login_password"
            type="password"
            label="Password"
            required
          />
          <:actions>
            <.button phx-disable-with="Logging in..." class="w-full">
              Log in <span aria-hidden="true">→</span>
            </.button>
          </:actions>
        </.simple_form>

        <.link
          href={~p"/users/guest"}
          method="post"
          class="mt-4 flex w-full justify-center rounded-lg px-3 py-2 text-sm font-semibold text-zinc-600 hover:text-zinc-900"
        >
          Continue as Guest
        </.link>
      </div>

      <div :if={@mode == :register} class="mt-8">
        <.simple_form
          for={@register_form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
          action={~p"/users/log_in?_action=registered"}
          method="post"
        >
          <.error :if={@check_errors}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <.input field={@register_form[:username]} type="text" label="Username" required />
          <.input field={@register_form[:password]} type="password" label="Password" required />

          <:actions>
            <.button phx-disable-with="Creating account..." class="w-full">
              Create account
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(mode: :login, trigger_submit: false, check_errors: false)
      |> assign(login_form: to_form(%{"username" => "", "password" => ""}, as: "user"))
      |> assign_register_form(changeset)

    {:ok, socket}
  end

  def handle_event("switch_mode", %{"mode" => "login"}, socket) do
    {:noreply, assign(socket, mode: :login)}
  end

  def handle_event("switch_mode", %{"mode" => "register"}, socket) do
    {:noreply, assign(socket, mode: :register)}
  end

  def handle_event("switch_mode", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    %{"username" => username, "password" => password} = user_params

    case Accounts.register_named_user(username, password) do
      {:ok, user} ->
        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_register_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_register_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_register_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_register_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, register_form: form, check_errors: false)
    else
      assign(socket, register_form: form)
    end
  end
end
