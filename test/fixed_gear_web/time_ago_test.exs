defmodule FixedGearWeb.TimeAgoTest do
  use ExUnit.Case, async: true

  use Gettext, backend: FixedGearWeb.Gettext

  alias FixedGearWeb.TimeAgo

  @now ~U[2026-09-21 15:00:00Z]

  test "formats relative timestamps" do
    assert TimeAgo.format(~U[2026-09-21 14:59:30Z], @now) == gettext("just now")

    assert TimeAgo.format(~U[2026-09-21 14:58:00Z], @now) ==
             ngettext("1 minute ago", "%{count} minutes ago", 2, count: 2)

    assert TimeAgo.format(~U[2026-09-21 12:00:00Z], @now) ==
             ngettext("1 hour ago", "%{count} hours ago", 3, count: 3)

    assert TimeAgo.format(~U[2026-09-19 15:00:00Z], @now) ==
             ngettext("1 day ago", "%{count} days ago", 2, count: 2)

    assert TimeAgo.format(~U[2026-07-21 15:00:00Z], @now) ==
             ngettext("1 month ago", "%{count} months ago", 2, count: 2)

    assert TimeAgo.format(~U[2024-09-21 15:00:00Z], @now) ==
             ngettext("1 year ago", "%{count} years ago", 2, count: 2)
  end
end
