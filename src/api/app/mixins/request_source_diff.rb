# this overwrites the sourcediff function for submit requests and maintenance
module RequestSourceDiff
  class ActionSourceDiffer
    attr_accessor :action

    def perform(opts)
      gather_source_packages.map { |spkg|
        diff_for_source(spkg, opts)
      }.join
    end

    def gather_source_packages
      return [action.source_package] if action.bs_request_action_accept_info # the old package can be gone

      if action.source_package
        action.source_access_check!
        return [action.source_package]
      else
        prj = Project.find_by_name(action.source_project)
        return [] unless prj

        return prj.packages.map { |p|
          p.check_source_access!
          p.name
        }
      end
    end

    def diff_for_source(spkg, options = {})
      @target_project = action.target_project
      @target_package = action.target_package
      query = { 'cmd' => 'diff' }
      ai = action.bs_request_action_accept_info

      if ai
        # OBS 2.1 adds acceptinfo on request accept
        path = Package.source_path(@target_project, @target_package)
        query[:rev] = ai.xsrcmd5 || ai.srcmd5
        query[:orev] = ai.oxsrcmd5 || ai.osrcmd5 || '0'
        query[:oproject] = ai.oproject if ai.oproject
        query[:opackage] = ai.opackage if ai.opackage
      else
        # for requests not yet accepted or accepted with OBS 2.0 and before

        # the target is by default the _link target
        # maintenance_release creates new packages instance, but are changing the source only according to the link
        provided_in_other_action = check_for_local_linked_packages(spkg)
        # fallback name as last resort
        @target_package ||= action.source_package

        # maintenance incidents shall show the final result after release
        @target_project = action.target_releaseproject if action.target_releaseproject

        # maintenance release targets will have a base link
        tprj = Project.get_by_name(@target_project)
        if tprj && tprj.is_maintenance_release?
          tpkg = tprj.find_package(@target_package.gsub(/\.[^\.]*$/, ''))
          if tpkg
            if tpkg.project.is_maintenance_release? && tpkg.is_local_link?
              # use package container from former incident update
              @target_package = tpkg.linkinfo['package']
            else
              @target_project = tprj.name
              @target_package = tpkg.name
            end
          end
        end

        if Package.exists_by_project_and_name(@target_project, @target_package, follow_project_links: true)
          tpkg = Package.get_by_project_and_name(@target_project, @target_package)
        end

        path = Package.source_path(action.source_project, spkg)
        query[:filelimit] = 10000

        if !provided_in_other_action && !action.updatelink
          # do show the same diff multiple times, so just diff unexpanded so we see possible link changes instead
          # also get sure that the request would not modify the link in the target
          query[:expand] = 1
        end

        if tpkg
          query[:oproject] = @target_project
          query[:opackage] = @target_package
          query[:rev] = action.source_rev if action.source_rev
        elsif action.source_rev # Use source rev for diffing (if available)
          # No target package means diffing the source package against itself.
          query[:orev] = 0
          query[:rev] = action.source_rev
        else # Otherwise generate diff for latest source package revision
          # FIXME: move to Package model
          spkg_rev = Directory.find_hashed(project: action.source_project, package: spkg)['rev']
          query[:orev] = 0
          query[:rev] = spkg_rev
        end
      end
      # run diff
      query[:view] = 'xml' if options[:view] == 'xml' # Request unified diff in full XML view
      query[:withissues] = 1 if options[:withissues]
      BsRequestAction.get_package_diff(path, query)
    end

    def check_for_local_linked_packages(spkg)
      # the target is by default the _link target
      # maintenance_release creates new packages instance, but are changing the source only according to the link
      return if action.target_package && action.action_type == :maintenance_incident
      begin
        data = Xmlhash.parse(Backend::Api::Sources::Package.files(action.source_project, spkg))
      rescue ActiveXML::Transport::Error
        return
      end
      linkinfo = data['linkinfo']
      return unless linkinfo
      @target_project ||= linkinfo["project"]
      @target_package ||= linkinfo["package"]
      return unless linkinfo["project"] == action.source_project
      # a local link, check if the real source change gets also transported in a seperate action
      action.bs_request.bs_request_actions.any? { |a| check_action_target(a, linkinfo["package"]) } if action.bs_request
    end

    # check if the action is the same target
    def check_action_target(other, linked_package_name)
      action.source_project == other.source_project &&
        linked_package_name == other.source_package &&
        action.target_project == other.target_project
    end
  end

  def sourcediff(opts = {})
    d = ActionSourceDiffer.new
    d.action = self
    d.perform(opts)
  end
end
