module Webui
  module Projects
    class StatusController < WebuiController
      before_action :set_project

      def show
        all_packages = 'All Packages'
        no_project = 'No Project'
        @no_project = '_none_'
        @all_projects = '_all_'
        @current_develproject = params[:filter_devel] || all_packages
        @filter = @current_develproject
        if @filter == all_packages
          @filter = @all_projects
        elsif @filter == no_project
          @filter = @no_project
        end
        @ignore_pending = params[:ignore_pending] || false
        @limit_to_fails = params[:limit_to_fails] != 'false'
        @limit_to_old = !(params[:limit_to_old].nil? || params[:limit_to_old] == 'false')
        @include_versions = !(!params[:include_versions].nil? && params[:include_versions] == 'false')
        @filter_for_user = params[:filter_for_user]

        @develprojects = {}
        ps = calc_status(params[:project_name])

        @packages = ps[:packages]
        @develprojects = ps[:projects].sort_by(&:downcase)
        @develprojects.insert(0, all_packages)
        @develprojects.insert(1, no_project)

        respond_to do |format|
          format.json do
            render json: ActiveSupport::JSON.encode(@packages)
          end
          format.html
        end
      end

      private

      def calc_status(project_name)
        @api_obj = Project.includes(:packages).find_by!(name: project_name)
        @status = {}

        # needed to map requests to package id
        @name2id = {}

        @prj_status = Rails.cache.fetch("prj_status-#{@api_obj}", expires_in: 5.minutes) do
          ProjectStatus::Calculator.new(@api_obj).calc_status(pure_project: true)
        end

        status_filter_packages
        status_gather_attributes
        status_gather_requests

        @packages = []
        @status.each_value do |p|
          status_check_package(p)
        end

        { packages: @packages, projects: @develprojects.keys }
      end

      def status_check_package(package)
        currentpack = {}
        pname = package.name

        currentpack['requests_from'] = []
        key = "#{@api_obj.name}/#{pname}"
        if @submits.key?(key)
          return if @ignore_pending

          currentpack['requests_from'].concat(@submits[key])
        end

        currentpack['name'] = pname
        currentpack['failedcomment'] = package.failed_comment if package.failed_comment.present?

        newest = 0

        package.fails.each do |repo, arch, time, md5|
          next if newest > time
          next if md5 != package.verifymd5

          currentpack['failedarch'] = arch
          currentpack['failedrepo'] = repo
          newest = time
          currentpack['firstfail'] = newest
        end
        return if !currentpack['firstfail'] && @limit_to_fails

        currentpack['problems'] = []
        currentpack['requests_to'] = []

        currentpack['md5'] = package.verifymd5

        check_devel_package_status(currentpack, package)
        currentpack.merge!(project_status_set_version(package))

        if package.links_to && (currentpack['md5'] != package.links_to.verifymd5)
          currentpack['problems'] << 'diff_against_link'
          currentpack['lproject'] = package.links_to.project
          currentpack['lpackage'] = package.links_to.name
        end

        return unless currentpack['firstfail'] || currentpack['failedcomment'] || currentpack['upstream_version'] ||
                      !currentpack['problems'].empty? || !currentpack['requests_from'].empty? || !currentpack['requests_to'].empty?

        return if @limit_to_old && !currentpack['upstream_version']

        @packages << currentpack
      end

      def check_devel_package_status(currentpack, p)
        dp = p.develpack
        return unless dp

        dproject = dp.project
        currentpack['develproject'] = dproject
        currentpack['develpackage'] = dp.name
        key = "#{dproject}/#{dp.name}"
        currentpack['requests_to'].concat(@submits[key]) if @submits.key?(key)

        currentpack['develmd5'] = dp.verifymd5
        currentpack['develmtime'] = dp.maxmtime

        currentpack['problems'] << "error-#{dp.error}" if dp.error

        return unless currentpack['md5'] && currentpack['develmd5'] && currentpack['md5'] != currentpack['develmd5']

        if p.declined_request
          @declined_requests[p.declined_request].bs_request_actions.each do |action|
            next unless action.source_project == dp.project && action.source_package == dp.name

            sourcerev = Rails.cache.fetch("rev-#{dp.project}-#{dp.name}-#{currentpack['md5']}") do
              Directory.hashed(project: dp.project, package: dp.name)['rev']
            end
            if sourcerev == action.source_rev
              currentpack['currently_declined'] = p.declined_request
              currentpack['problems'] << 'currently_declined'
            end
          end
        end

        return unless currentpack['currently_declined'].nil?
        return currentpack['problems'] << 'different_changes' if p.changesmd5 != dp.changesmd5

        currentpack['problems'] << 'different_sources'
      end

      def status_filter_packages
        filter_for_user = User.find_by_login!(@filter_for_user) if @filter_for_user.present?
        current_develproject = @filter || @all_projects
        @develprojects = {}
        packages_to_filter_for = nil
        packages_to_filter_for = filter_for_user.user_relevant_packages_for_status if filter_for_user
        @prj_status.each_value do |value|
          if value.develpack
            dproject = value.develpack.project
            @develprojects[dproject] = 1
            next if (current_develproject != dproject || current_develproject == @no_project) && current_develproject != @all_projects
          elsif @current_develproject == @no_project
            next
          end
          if filter_for_user
            if value.develpack
              next unless packages_to_filter_for.include?(value.develpack.package_id)
            else
              next unless packages_to_filter_for.include?(value.package_id)
            end
          end
          @status[value.package_id] = value
          @name2id[value.name] = value.package_id
        end
      end

      def status_gather_requests
        # we do not filter requests for project because we need devel projects too later on and as long as the
        # number of open requests is limited this is the easiest solution
        raw_requests = BsRequest.order(:number).where(state: %i[new review declined]).joins(:bs_request_actions)
                                .where(bs_request_actions: { type: %w[submit delete] }).pluck('bs_requests.number',
                                                                                              'bs_requests.state',
                                                                                              'bs_request_actions.target_project',
                                                                                              'bs_request_actions.target_package')

        @declined_requests = {}
        @submits = {}
        raw_requests.each do |number, state, tproject, tpackage|
          if state == 'declined'
            next if tproject != @api_obj.name || !@name2id.key?(tpackage)

            @status[@name2id[tpackage]].declined_request = number
            @declined_requests[number] = nil
          else
            key = "#{tproject}/#{tpackage}"
            @submits[key] ||= []
            @submits[key] << number
          end
        end
        BsRequest.where(number: @declined_requests.keys).find_each do |r|
          @declined_requests[r.number] = r
        end
      end

      def status_gather_attributes
        ProjectStatusControllerService::ProjectStatusFailCommentFinder.call(@status.keys).each do |package, value|
          @status[package].failed_comment = value
        end

        return unless @include_versions || @limit_to_old

        ProjectStatusControllerService::OpenSUSEUpstreamVersionFinder.call(@status.keys).each do |package, value|
          @status[package].upstream_version = value
        end

        ProjectStatusControllerService::OpenSUSEUpstreamTarballURLFinder.call(@status.keys).each do |package, value|
          @status[package].upstream_url = value
        end
      end

      def project_status_set_version(p)
        ret = {}
        ret['version'] = p.version
        if p.upstream_version
          begin
            gup = Gem::Version.new(p.version)
            guv = Gem::Version.new(p.upstream_version)
          rescue ArgumentError
            # if one of the versions can't be parsed we simply can't say
          end

          if gup && guv && gup < guv
            ret['upstream_version'] = p.upstream_version
            ret['upstream_url'] = p.upstream_url
          end
        end
        ret
      end
    end
  end
end
