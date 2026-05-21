module Webui::UserActivityHelper
  def percentil(length, ratio)
    (length * ratio).round - 1
  end

  def contributions_percentiles(contributions_array)
    contributions_values = contributions_array.sort
    contributions_array_length = contributions_values.length

    # We take the 50th, 80th and 95 percentil to ensure we have some of each
    # color, giving the feeling that there are not many high ones
    percentil1 = contributions_values[percentil(contributions_array_length, 0.5)]
    percentil2 = contributions_values[percentil(contributions_array_length, 0.8)]
    percentil3 = contributions_values[percentil(contributions_array_length, 0.95)]

    [percentil1, percentil2, percentil3]
  end

  def activity_classname(activity, percentiles)
    if activity.zero?
      ''
    elsif activity <= percentiles[0]
      'table-activity-percentil1'
    elsif activity <= percentiles[1]
      'table-activity-percentil2'
    elsif activity <= percentiles[2]
      'table-activity-percentil3'
    else
      'table-activity-percentil4'
    end
  end

  def contribution_graph?
    CONFIG['contribution_graph'] != :off
  end
end
