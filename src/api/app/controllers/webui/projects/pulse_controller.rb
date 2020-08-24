module Webui
  module Projects
    class PulseController < WebuiController
      before_action :forbid_bot_access
      before_action :set_project
      before_action :set_range
      before_action :set_pulse

      def show
        @pulse = @project.project_log_entries.page(params[:page])
      end

      private

      def forbid_bot_access
        return head :forbidden if request.bot?
      end

      def set_range
        @range = params[:range] == 'month' ? 'month' : 'week'
      end

      def set_pulse
        range = case @range
                when 'month'
                  1.month.ago..Date.tomorrow
                else
                  1.week.ago..Date.tomorrow
                end

        pulse = @project.project_log_entries.where(datetime: range).order(datetime: :asc)
        @builds = pulse.where(event_type: [:build_fail, :build_success]).where(datetime: 24.hours.ago..Time.zone.now)
        @new_packages = pulse.where(event_type: :create_package)
        @deleted_packages = pulse.where(event_type: :delete_package)
        @branches = pulse.where(event_type: :branch_command)
        @commits = pulse.where(event_type: :commit)
        @updates = pulse.where(event_type: :version_change)
        @comments = pulse.where(event_type: [:comment_for_package, :comment_for_project])
        @project_changes = pulse.where(event_type: [:update_project, :update_project_config])

        @requests = @project.target_of_bs_requests.where(updated_at: range).order(updated_at: :desc)
        # group by state, sort by value...
        @requests_by_state = @requests.group(:state).count.sort_by { |_, v| -v }.to_h
        # transpose to percentages
        @requests_by_percentage = @requests_by_state.each_with_object({}) { |(k, v), hash| hash[k] = (v * 100.0 / @requests_by_state.values.sum).round.to_s } if @requests_by_state.any?
      end
    end
  end
end
