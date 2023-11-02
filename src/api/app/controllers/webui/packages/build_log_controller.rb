module Webui
  module Packages
    class BuildLogController < Webui::WebuiController
      include BuildLogSupport

      before_action :check_ajax, only: :update_build_log
      before_action :check_build_log_access

      def live_build_log
        @repo = @project.repositories.find_by(name: params[:repository]).try(:name)
        unless @repo
          flash[:error] = "Couldn't find repository '#{params[:repository]}'. Are you sure it still exists?"
          redirect_to(package_show_path(@project, @package))
          return
        end

        @arch = Architecture.archcache[params[:arch]].try(:name)
        unless @arch
          flash[:error] = "Couldn't find architecture '#{params[:arch]}'. Are you sure it still exists?"
          redirect_to(package_show_path(@project, @package))
          return
        end

        @offset = 0
        @status = get_status(@project, @package_name, @repo, @arch)
        @what_depends_on = Package.what_depends_on(@project, @package_name, @repo, @arch)
        @finished = Buildresult.final_status?(status)

        set_job_status
      end

      def update_build_log
        # Make sure objects don't contain invalid chars (eg. '../')
        @repo = @project.repositories.find_by(name: params[:repository]).try(:name)
        unless @repo
          @errors = "Couldn't find repository '#{params[:repository]}'. We don't have build log for this repository"
          return
        end

        @arch = Architecture.archcache[params[:arch]].try(:name)
        unless @arch
          @errors = "Couldn't find architecture '#{params[:arch]}'. We don't have build log for this architecture"
          return
        end

        begin
          @maxsize = 1024 * 64
          @first_request = params[:initial] == '1'
          @offset = params[:offset].to_i
          @status = get_status(@project, @package_name, @repo, @arch)
          @finished = Buildresult.final_status?(@status)
          @size = get_size_of_log(@project, @package_name, @repo, @arch)

          chunk_start = @offset
          chunk_end = @offset + @maxsize

          # Start at the most recent part to not get the full log from the begining just the last 64k
          if @first_request && (@finished || @size >= @maxsize)
            chunk_start = [0, @size - @maxsize].max
            chunk_end = @size
          end

          @log_chunk = get_log_chunk(@project, @package_name, @repo, @arch, chunk_start, chunk_end)

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
      end

      private

      # Basically backend stores date in /source (package sources) and /build (package
      # build related). Logically build logs are stored in /build. Though build logs also
      # contain information related to source packages.
      # Thus before giving access to the build log, we need to ensure user has source access
      # rights.
      #
      # This before_filter checks source permissions for packages that belong
      # to local projects and local projects that link to other project's packages.
      #
      # If the check succeeds it sets @project and @package variables.
      def check_build_log_access
        @project = Project.find_by(name: params[:project])
        unless @project
          redirect_to root_path, error: "Couldn't find project '#{params[:project]}'. Are you sure it still exists?"
          return false
        end

        @package_name = params[:package]
        begin
          @package = Package.get_by_project_and_name(@project, @package_name, use_source: false,
                                                                              follow_multibuild: true)
        rescue Package::UnknownObjectError
          redirect_to project_show_path(@project.to_param),
                      error: "Couldn't find package '#{params[:package]}' in " \
                             "project '#{@project.to_param}'. Are you sure it exists?"
          return false
        end

        # NOTE: @package is a String for multibuild packages
        @package = Package.find_by_project_and_name(@project.name, Package.striping_multibuild_suffix(@package_name)) if @package.is_a?(String)

        unless @package.check_source_access?
          redirect_to package_show_path(project: @project.name, package: @package_name),
                      error: 'Could not access build log'
          return false
        end

        @can_modify = User.possibly_nobody.can_modify?(@project) || User.possibly_nobody.can_modify?(@package)

        true
      end

      def set_job_status
        @percent = nil

        begin
          jobstatus = get_job_status(@project, @package_name, @repo, @arch)
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
