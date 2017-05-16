namespace :statistics do
  desc 'Exports the current number of users, projects, packages, etc. to a file'
  task current_numbers: :environment do
    # The context of the file is NOT prepared to be used by R, just a easy way to get useful information
    information = "OBS STATISTICS ON " + Date.today.to_s + "\n\n"
    information += ("Number of users: " + User.count.to_s + "\n")
    information += ("Number of projects: " + Project.count.to_s + "\n")
    information += ("Number of packages: " + Package.count.to_s + "\n")

    out_file = File.new("current.txt", "w")
    out_file.puts(information)
    out_file.close
  end
end
