
# frozen_string_literal: true

xml.active_request_creators(project: @project.name) do
  @stats.each do |month, monthstats|
    xml.per_month(month: month) do
      monthstats.each do |creator, email, count|
        xml.creator(login: creator, email: email, count: count)
      end
    end
  end
end
