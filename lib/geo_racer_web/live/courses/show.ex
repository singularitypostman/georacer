defmodule GeoRacerWeb.Live.Courses.Show do
  @moduledoc false
  alias GeoRacer.Races
  alias GeoRacer.Races.{StagingArea, Race}
  alias GeoRacerWeb.Router.Helpers, as: Routes
  use Phoenix.LiveView

  def render(assigns) do
    Phoenix.View.render(GeoRacerWeb.CourseView, "show.html", assigns)
  end

  def mount(session, socket) do
    case Races.by_course_id_and_code(session.course.id, session.code) do
      %Race.Impl{} = race ->
        {:stop, redirect(socket, to: Routes.race_path(GeoRacerWeb.Endpoint, :show, race.id))}

      nil ->
        StagingArea.put_team("#{session.course.id}:#{session.code}", session.current_team)
        StagingArea.subscribe_to_updates(session.course.id, session.code)
        send(self(), {:setup, session})
        {:ok, assign(socket, code: session.code, course: session.course, teams: [])}
    end
  end

  def handle_info({:setup, %{course: course, code: code} = session}, socket) do
    %{teams: teams} = StagingArea.state("#{course.id}:#{code}")

    socket =
      socket
      |> assign(:current_team, session.current_team)
      |> assign(:teams, teams)

    {:noreply, socket}
  end

  def handle_info(%{event: "update", payload: %StagingArea.Impl{} = staging_area}, socket) do
    {:noreply, assign(socket, :teams, staging_area.teams)}
  end

  def handle_info(%{event: "redirect_to_race", payload: %{race_id: race_id}}, socket) do
    {:stop, redirect(socket, to: Routes.race_path(GeoRacerWeb.Endpoint, :show, race_id))}
  end

  def handle_event("start_race", _, %{assigns: %{course: course, code: code}} = socket) do
    case Races.create_from_staging_area(StagingArea.state("#{course.id}:#{code}")) do
      {:ok, %Race.Impl{} = race} ->
        StagingArea.force_redirect_to_race("#{course.id}:#{code}", race.id)
        {:stop, redirect(socket, to: Routes.race_path(GeoRacerWeb.Endpoint, :show, race.id))}

      _ ->
        {:noreply, socket}
    end
  end
end
