# frozen_string_literal: true
namespace :statistics do
  namespace :github do
    desc 'Exports the number of commits per week for the last year to a file'
    task commit_activity: :environment do
      uri = URI('https://api.github.com/repos/openSUSE/open-build-service/stats/commit_activity')
      response = Net::HTTP.get_response(uri)

      # The first time you make this request to github, it returns an empty json response with status 202
      # because github generates the statistics asynchronously. Once they are generated will be 200.
      if response.code == '202'
        puts 'Statistics are being generated in the background by github. Please re-run this task in a minute to get the results.'
      elsif response.code == '200'
        weeks = JSON.parse(response.body)

        File.open('commit_activity.csv', 'w') do |file|
          file.write("date, commits\n")

          weeks.map do |week|
            timestamp = week['week']
            commits = week['total']

            line = Time.at(timestamp).strftime('%Y-%m-%d') + ", #{commits}"
            file.write(line + "\n")
          end
        end

        puts 'Statistics written to commit_activity.csv'
      end
    end
  end
end
