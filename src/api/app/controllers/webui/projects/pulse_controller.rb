module Webui
  module Projects
    class PulseController < WebuiController
      before_action :lockout_spiders, only: [:show]
      before_action :set_project
      before_action :set_range

      def show
        respond_to do |format|
          format.js do
            pulse = @project.project_log_entries.where(datetime: @date_range).order(datetime: :asc)

            requests = @project.target_of_bs_requests.where(updated_at: @date_range).order(updated_at: :desc)
            requests_by_state = requests.group(:state).count.sort_by { |_, v| -v }.to_h
            requests_by_percentage = requests_by_state.each_with_object({}) do |(k, v), hash|
              hash[k] = (v * 100.0 / requests_by_state.values.sum).round.to_s
            end

            render partial: 'pulse_list', locals: { project: @project,
                                                    builds: pulse.where(event_type: %i[build_fail build_success])
                                                                 .where(datetime: 24.hours.ago..Time.zone.now),
                                                    new_packages: pulse.where(event_type: :create_package),
                                                    deleted_packages: pulse.where(event_type: :delete_package),
                                                    branches: pulse.where(event_type: :branch_command),
                                                    commits: pulse.where(event_type: :commit),
                                                    updates: pulse.where(event_type: :version_change),
                                                    comments: pulse.where(event_type: %i[comment_for_package comment_for_project]),
                                                    project_changes: pulse.where(event_type: %i[update_project update_project_config]),
                                                    requests: requests,
                                                    requests_by_state: requests_by_state,
                                                    requests_by_percentage: requests_by_percentage }
          end
          format.html
        end
      end

      private

      def set_range
        @range = params[:range] == 'month' ? 'month' : 'week'

        @date_range = case @range
                      when 'month'
                        1.month.ago..Date.tomorrow
                      else
                        1.week.ago..Date.tomorrow
                      end
      end
    end
  end
end
