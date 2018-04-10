# frozen_string_literal: true
namespace :statistics do
  namespace :github do
    desc 'Export the number of issues merged per week to a file'
    task issues: :environment do
      # GITHUB login required in order to avoid rate limiting on http requests
      GITHUB_USERNAME = ''.freeze
      GITHUB_PASSWORD = ''.freeze

      if GITHUB_USERNAME.empty? || GITHUB_PASSWORD.empty?
        raise StandardError, "Please set your github username/password in lines 8&9 of this file:\nlib/tasks/statistics/github/issues.rake"
      end

      issues = []
      on_last_page = false
      page = 1

      while on_last_page == false
        issues_current, links_current = get_merged_issues(page)

        issues += issues_current

        on_last_page = on_last_page?(links_current)
        page += 1
      end

      issues_grouped_by_week =
        issues
        .map { |issue| Date.parse(issue['created_at']) }
        .group_by { |date| (date - date.wday).strftime('%Y-%m-%d') }

      output = {}
      issues_grouped_by_week.each do |week, issues_in_week|
        output[week] = issues_in_week.count
      end

      write_issues_to_file(output)
    end

    def get_merged_issues(page)
      puts "Requesting issues page #{page}..."
      uri = URI("https://api.github.com/repos/openSUSE/open-build-service/issues?filter=all&state=all&page=#{page}")

      response =
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
          request = Net::HTTP::Get.new uri.request_uri
          request.basic_auth GITHUB_USERNAME, GITHUB_PASSWORD

          http.request(request)
        end

      raise StandardError, response.body if response.code != '200'

      issues = JSON.parse(response.body)
      link_header = response.get_fields('Link').first
      links = link_header.split(', ')

      [issues, links]
    end

    def write_issues_to_file(dates_and_issues)
      File.open('issues.csv', 'w') do |file|
        file.write("week, number_issues_created\n")

        dates_and_issues.each do |week, number_issues|
          file.write("#{week}, #{number_issues}\n")
        end

        puts 'Statistics written to issues.csv'
      end
    end
  end
end
