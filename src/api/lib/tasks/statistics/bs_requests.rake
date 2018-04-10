# frozen_string_literal: true
namespace :statistics do
  desc 'Exports the number of bs requests actions per month to a file'
  task number_bs_requests: :environment do
    # The context of the file is prepared to be used by R
    information = "date, bs_requests, bs_requests_increase\n"
    # We want the bs_request at the last day of every period
    # To query before this date it is needed to make a join an take the date from BsRequest
    # as BsRequestAction was introduced at the end of 2012
    # Most likely you want not to take into account Admin user, as it is not representative
    # of the collaboration activity.
    date = Date.new(2013, 1, 1)
    # date = Date.new(2008,4,1)
    old_bs_requests = 0
    while date < Time.zone.today
      num_bs_requests = BsRequestAction.joins(:bs_request).where('bs_requests.created_at < ? AND bs_requests.creator != ?', date, 'Admin').count
      information += "#{date}, #{num_bs_requests}, #{num_bs_requests - old_bs_requests}\n"
      # granularity, currently it is one month. Adjust it as needed
      date += 1.month
      old_bs_requests = num_bs_requests
    end
    out_file = File.new('number_bs_requests.txt', 'w')
    out_file.puts(information)
    out_file.close
  end

  desc 'Exports the number of bs requests for a project per month to a file'
  task :number_bs_requests_for_project, [:project] => [:environment] do |_t, args|
    # The context of the file is prepared to be used by R
    information = "date, bs_requests, bs_requests_increase\n"
    # We want the bs_request at the last day of every period
    # To query before this date it is needed to make a join an take the date from BsRequest
    # as BsRequestAction was introduced at the end of 2012
    # Most likely you want not to take into account Admin user, as it is not representative
    # of the collaboration activity.
    date = Date.new(2013, 1, 1)
    # date = Date.new(2008,4,1)
    old_bs_requests = 0
    while date < Time.zone.today
      num_bs_requests = BsRequestAction
                        .joins(:bs_request)
                        .where('bs_requests.created_at < ? AND bs_requests.creator != ? AND bs_request_actions.target_project LIKE ?',
                               date,
                               'Admin',
                               "#{args[:project]}%")
                        .count
      information += "#{date}, #{num_bs_requests}, #{num_bs_requests - old_bs_requests}\n"
      # granularity, currently it is one month. Adjust it as needed
      date += 1.month
      old_bs_requests = num_bs_requests
    end
    out_file = File.new("number_bs_requests_for_#{args[:project]}.txt", 'w')
    out_file.puts(information)
    out_file.close
  end

  desc 'Exports the number of projects with bs requests per month to a file'
  task number_projects_bs_requests: :environment do
    # The context of the file is prepared to be used by R
    information = "date, projects_bs_requests, projects_bs_requests_increase\n"
    # We want the bs_request at the last day of every period
    # To query before this date it is needed to make a join an take the date from BsRequest
    # as BsRequestAction was introduced at the end of 2012
    date = Date.new(2013, 1, 1)
    while date < Time.zone.today
      num_bs_requests = BsRequestAction.where('created_at < ? AND created_at >= ?', date, date - 1.month).group('target_project').count.length
      information += "#{date}, #{num_bs_requests}\n"
      # granularity, currently it is one month. Adjust it as needed
      date += 1.month
    end
    out_file = File.new('number_projects_bs_requests.txt', 'w')
    out_file.puts(information)
    out_file.close
  end
end
