defmodule FixedGearWeb.TimeAgo do
  @moduledoc false

  use Gettext, backend: FixedGearWeb.Gettext

  @minute 60
  @hour 60 * @minute
  @day 24 * @hour
  @month 30 * @day
  @year 365 * @day

  def format(%DateTime{} = datetime, now \\ DateTime.utc_now()) do
    seconds = max(DateTime.diff(now, datetime, :second), 0)

    cond do
      seconds < @minute ->
        gettext("just now")

      seconds < @hour ->
        count = div(seconds, @minute)
        ngettext("1 minute ago", "%{count} minutes ago", count, count: count)

      seconds < @day ->
        count = div(seconds, @hour)
        ngettext("1 hour ago", "%{count} hours ago", count, count: count)

      seconds < @month ->
        count = div(seconds, @day)
        ngettext("1 day ago", "%{count} days ago", count, count: count)

      seconds < @year ->
        count = div(seconds, @month)
        ngettext("1 month ago", "%{count} months ago", count, count: count)

      true ->
        count = div(seconds, @year)
        ngettext("1 year ago", "%{count} years ago", count, count: count)
    end
  end
end
