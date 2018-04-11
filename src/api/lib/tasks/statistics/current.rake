# frozen_string_literal: true

namespace :statistics do
  desc 'Exports the current number of users, projects, packages, etc. to a file'
  task current_numbers: :environment do
    # The context of the file is NOT prepared to be used by R, just a easy way to get useful information
    elements = HistoryElement::Request
               .where(type: 'HistoryElement::RequestAccepted')
               .joins('INNER JOIN bs_requests ON bs_requests.id = history_elements.op_object_id')
               .pluck('bs_requests.created_at', 'history_elements.created_at')
    time = elements.sum { |element| element[1].to_i - element[0].to_i }
    time_in_hours = time / elements.count / 60 / 60

    information = ''"OBS STATISTICS ON #{Time.zone.today}\n
                  Number of users: #{User.count}
                  Number of projects: #{Project.count}
                  Number of packages: #{Package.count}
                  Average time to accept a request: #{time_in_hours} hours
                  "''

    out_file = File.new('current.txt', 'w')
    out_file.puts(information)
    out_file.close
  end
end
