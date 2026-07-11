defmodule RiftboardWeb.UserLoginLiveTest do
  use RiftboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Riftboard.AccountsFixtures

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log_in")

      assert html =~ "Log in"
      assert html =~ "Create account"
      assert html =~ "Continue as Guest"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/log_in")
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end

    test "clicking the segmented control switches between login and register forms", %{
      conn: conn
    } do
      {:ok, lv, html} = live(conn, ~p"/users/log_in")
      assert html =~ ~s|id="login_form"|
      refute html =~ ~s|id="registration_form"|

      html = lv |> element("button[phx-value-mode='register']") |> render_click()
      refute html =~ ~s|id="login_form"|
      assert html =~ ~s|id="registration_form"|

      html = lv |> element("button[phx-value-mode='login']") |> render_click()
      assert html =~ ~s|id="login_form"|
      refute html =~ ~s|id="registration_form"|
    end
  end

  describe "user login" do
    test "redirects if user login with valid credentials", %{conn: conn} do
      password = "123456789abcd"
      user = user_fixture(%{password: password})

      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      form = form(lv, "#login_form", user: %{username: user.username, password: password})

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if there are no valid credentials", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      form =
        form(lv, "#login_form", user: %{username: "unknown_user", password: "123456"})

      conn = submit_form(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid username or password"

      assert redirected_to(conn) == "/users/log_in"
    end
  end

  describe "register user" do
    test "creates account and logs the user in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")
      lv |> element("button[phx-value-mode='register']") |> render_click()

      username = unique_username()
      form = form(lv, "#registration_form", user: valid_user_attributes(username: username))
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the header (root redirects to /boards)
      conn = get(conn, "/")
      response = conn |> get(redirected_to(conn)) |> html_response(200)
      assert response =~ username
      assert response =~ "Log out"
    end

    test "renders errors for duplicated username", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")
      lv |> element("button[phx-value-mode='register']") |> render_click()

      user = user_fixture(%{username: "taken_username"})

      result =
        lv
        |> form("#registration_form",
          user: %{"username" => user.username, "password" => "valid_password"}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")
      lv |> element("button[phx-value-mode='register']") |> render_click()

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"username" => "ab", "password" => "too short"})

      assert result =~ "should be at least 3 character"
      assert result =~ "should be at least 12 character"
    end
  end
end
