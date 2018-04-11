# frozen_string_literal: true

namespace :statistics do
  desc 'Exports the number of confirmed users per month to a file'
  task number_users: :environment do
    # The context of the file is prepared to be used by R
    information = "date, users, users_increase\n"
    # we want the user at the last day of every period
    date = Date.new(2006, 0o2, 0o1)
    old_users = 0
    while date < Time.zone.today
      # locked users could also be considered here
      num_users = User.where('created_at < ? AND state = ?', date, 'confirmed').count
      information += "#{date}, #{num_users}, #{num_users - old_users}\n"
      # granularity, currently it is one month. Adjust it as needed
      date += 1.day
      old_users = num_users
    end
    out_file = File.new('number_users.txt', 'w')
    out_file.puts(information)
    out_file.close
  end
end
