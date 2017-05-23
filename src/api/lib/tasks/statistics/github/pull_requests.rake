require 'net/http'

# GITHUB login required in order to avoid rate limiting on http requests
GITHUB_USERNAME = ''
GITHUB_PASSWORD = ''

namespace :statistics do
  namespace :github do
    desc 'Export the number of pull requests merged per week to a file'
    task pull_requests: :environment do
      if GITHUB_USERNAME.empty? || GITHUB_PASSWORD.empty?
        raise StandardError, "Please set your github username/password in lines 3&4 of this file:\nlib/tasks/statistics/github/pull_requests.rake"
      end

      dates_and_merges = {}
      on_last_page = false
      page = 1

      while on_last_page == false
        dates_and_merges_current, links_current = get_dates_and_merges(page)

        dates_and_merges.merge!(dates_and_merges_current)

        on_last_page = on_last_page?(links_current)
        page += 1
      end

      write_to_file(dates_and_merges)
    end

    def get_dates_and_merges(page)
      puts "Requesting pull requests page #{page}..."
      uri = URI("https://api.github.com/repos/openSUSE/open-build-service/pulls?state=closed&page=#{page}")

      response =
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
          request = Net::HTTP::Get.new uri.request_uri
          request.basic_auth GITHUB_USERNAME, GITHUB_PASSWORD

          http.request(request)
        end

      raise StandardError, response.body if response.code != '200'

      pull_requests = JSON.parse(response.body)
      link_header = response.get_fields('Link').first
      links = link_header.split(', ')

      dates_and_merges =
        pull_requests
          .select { |pull_request| pull_request['merged_at'].present? }
          .map { |pull_request| Date.parse(pull_request['merged_at']) }
          .group_by { |date| (date - date.wday).strftime('%Y-%m-%d') }

      dates_and_merges.each { |week, dates| dates_and_merges[week] = dates.count }

      [dates_and_merges, links]
    end

    def on_last_page?(links)
      link_rel = links.first.match(/.*rel=\"(\w+*)\"/).captures.first
      link_rel == 'first'
    end

    def write_to_file(dates_and_merges)
      File.open('pull_requests.csv', 'w') do |file|
        file.write("week, number_pull_requests_merged\n")

        dates_and_merges.each do |week, number_merges|
          file.write("#{week}, #{number_merges}\n")
        end

        puts 'Statistics written to pull_requests.csv'
      end
    end
  end
end

