namespace :statistics do
  desc 'Exports the number of confirmed users per month to a file'
  task number_users: :environment do
    # The context of the file is prepared to be used by R
    information = "date, users, users_increase\n"
    # we want the user at the last day of every period
    date = Date.new(2006,02,01)
    old_users = 0
    while date < Date.today
      num_users = User.where('created_at < ? AND state = ?', date, 'confirmed').count
      information += (date.to_s + ", " + num_users.to_s + ", " + (num_users - old_users).to_s + "\n")
      # granularity, currently it is one month. Adjust it as needed
      date += 1.day
      old_users = num_users
    end
    out_file = File.new("number_users.txt", "w")
    out_file.puts(information)
    out_file.close
  end
end
