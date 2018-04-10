# frozen_string_literal: true
namespace :statistics do
  namespace :github do
    desc 'Exports the number of additions and deletions per week to a file'
    task code_frequency: :environment do
      uri = URI('https://api.github.com/repos/openSUSE/open-build-service/stats/code_frequency')
      response = Net::HTTP.get_response(uri)

      # The first time you make this request to github, it returns an empty json response with status 202
      # because github generates the statistics asynchronously. Once they are generated will be 200.
      if response.code == '202'
        puts 'Statistics are being generated in the background by github. Please re-run this task in a minute to get the results.'
      elsif response.code == '200'
        weeks = JSON.parse(response.body)

        File.open('code_frequency.csv', 'w') do |file|
          file.write("date, additions, deletions\n")

          weeks.map do |timestamp, additions, deletions|
            line = Time.at(timestamp).strftime('%Y-%m-%d') + ", #{additions}, #{deletions}"
            file.write(line + "\n")
          end
        end

        puts 'Statistics written to code_frequency.csv'
      end
    end
  end
end
