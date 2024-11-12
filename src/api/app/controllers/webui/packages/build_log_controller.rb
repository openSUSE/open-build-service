module Webui
  module Packages
    class BuildLogController < Webui::WebuiController
      include BuildLogSupport
      include Webui::NotificationsHandler

      before_action :check_ajax, only: :update_build_log
      before_action :set_project
      before_action :set_package
      before_action :set_repository
      before_action :set_architecture
      before_action :set_object_to_authorize

      def live_build_log
        @current_notification = handle_notification
        @offset = 0
        @status = get_status(@project, @package_name, @repository, @architecture)
        @what_depends_on = Package.what_depends_on(@project, @package_name, @repository, @architecture)
        @finished = Buildresult.final_status?(status)

        set_job_status
      end

      def update_build_log
        @maxsize = 1024 * 64
        @first_request = params[:initial] == '1'
        @offset = params[:offset].to_i
        @status = get_status(@project, @package_name, @repository, @architecture)
        @finished = Buildresult.final_status?(@status)
        @size = get_size_of_log(@project, @package_name, @repository, @architecture)

        chunk_start = @offset
        chunk_end = @offset + @maxsize

        # Start at the most recent part to not get the full log from the begining just the last 64k
        if @first_request && (@finished || @size >= @maxsize)
          chunk_start = [0, @size - @maxsize].max
          chunk_end = @size
        end

        @log_chunk = get_log_chunk(@project, @package_name, @repository, @architecture, chunk_start, chunk_end)

        old_offset = @offset
        @offset = [chunk_end, @size].min
      rescue Timeout::Error, IOError
        @log_chunk = ''
      rescue Backend::Error => e
        case e.summary
        when /Logfile is not that big/
          @log_chunk = ''
        when /start out of range/
          # probably build compare has cut log and offset is wrong, reset offset
          @log_chunk = ''
          @offset = old_offset
        else
          @log_chunk = "No live log available: #{e.summary}\n"
          @finished = true
        end
      end

      private

      def set_job_status
        @percent = nil

        begin
          jobstatus = get_job_status(@project, @package_name, @repository, @architecture)
          if jobstatus.present?
            js = Xmlhash.parse(jobstatus)
            @workerid = js.get('workerid')
            @buildtime = Time.now.to_i - js.get('starttime').to_i
            ld = js.get('lastduration')
            @percent = (@buildtime * 100) / ld.to_i if ld.present?
          end
        rescue StandardError
          @workerid = nil
          @buildtime = nil
        end
      end
    end
  end
end
