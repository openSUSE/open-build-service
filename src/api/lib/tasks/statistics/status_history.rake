namespace :statistics do
  desc 'Exports the monitoring query to a file'
  # task monitoring_events: :environment do
  task :monitoring_events, [:range, :end_date] => [:environment] do |_t, args|
    session = ActionDispatch::Integration::Session.new(Rails.application)

    parameters = { arch: 'x86_64', range: args[:range] }
    parameters[:end_date] = args[:end_date] if args[:end_date]
    session.get '/monitor/events', params: parameters, xhr: true

    information = session.body

    # Create the json output file
    out_file = File.new("statistics_monitoring_events.json", "w")
    out_file.puts(information)
    out_file.close

    # ar: all_results
    ar = JSON.parse information

    # First csv file
    information = "date, waiting, blocked, squeue_high, squeue_med\n"

    i = 0
    ar['waiting'].each do
      information += [Time.at(ar['waiting'][i][0] / 1000).strftime("%Y-%m-%d %H:%M:%S"),
                      ar['waiting'][i][1], ar['blocked'][i][1], ar['squeue_high'][i][1],
                      ar['squeue_med'][i][1]].join(', ') + "\n"
      i += 1
    end

    out_file = File.new("statistics_monitoring_events_1.csv", "w")
    out_file.puts(information)
    out_file.close

    # Second csv file
    information = "date, idle, building, away, down, dead\n"
    i = 0
    ar['idle'].each do
      information += [Time.at(ar['idle'][i][0] / 1000).strftime("%Y-%m-%d %H:%M:%S"),
                      ar['idle'][i][1], ar['building'][i][1], ar['away'][i][1],
                      ar['down'][i][1], ar['dead'][i][1]].join(', ') + "\n"
      i += 1
    end

    out_file = File.new("statistics_monitoring_events_2.csv", "w")
    out_file.puts(information)
    out_file.close
  end
end
