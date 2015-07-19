# this overwrites the sourcediff function for submit requests and maintenance
module RequestSourceDiff

  class ActionSourceDiffer

    attr_accessor :action

    def perform(opts)
      @view_xml = (opts[:view] == 'xml')
      @withissues = opts[:withissues]

      gather_source_packages.map { |spkg|
        diff_for_source(spkg, action.target_project, action.target_package)
      }.join
    end

    def gather_source_packages
      if action.bs_request_action_accept_info # the old package can be gone
        return [action.source_package]
      else
        if action.source_package
          action.source_access_check!
          return [action.source_package]
        else
          prj = Project.find_by_name(action.source_project)
          if prj
            return prj.packages.map { |p|
              p.check_source_access!
              p.name
            }
          else
            []
          end
        end
      end
    end

    def diff_for_source(spkg, target_project=nil, target_package=nil)
      @target_project = target_project || action.target_project
      @target_package = target_package || action.target_package

      # fallback name as last resort
      @target_package ||= action.source_package
      query = {'cmd' => 'diff'}
      ai = action.bs_request_action_accept_info
      if ai
        # OBS 2.1 adds acceptinfo on request accept
        path = Package.source_path(@target_project, @target_package)
        query[:rev] = ai.xsrcmd5 || ai.srcmd5
        query[:orev] = ai.oxsrcmd5 || ai.osrcmd5 || '0'
        query[:oproject] = ai.oproject if ai.oproject
        query[:opackage] = ai.opackage if ai.opackage
      else
        # the target is by default the _link target
        # maintenance_release creates new packages instance, but are changing the source only according to the link
        provided_in_other_action = overwrite_target_by_link(spkg)

        # maintenance incidents shall show the final result after release
        @target_project = action.target_releaseproject if action.target_releaseproject

        tprj = Project.get_by_name(@target_project)

        # maintenance release targets will have a base link
        @target_package.gsub!(/\.[^\.]$/, '') if tprj.is_maintenance_release?

        # for requests not yet accepted or accepted with OBS 2.0 and before
        tpkg = tprj = nil
        if Package.exists_by_project_and_name(@target_project, @target_package, follow_project_links: true)
          tpkg = Package.get_by_project_and_name(@target_project, @target_package)
        end

        path = Package.source_path(action.source_project, spkg)
        query[:filelimit] = 10000

        unless provided_in_other_action
          # do show the same diff multiple times, so just diff unexpanded so we see possible link changes instead
          # also get sure that the request would not modify the link in the target
          query[:expand] = 1 unless action.updatelink
        end
        if tpkg
          query[:oproject] = @target_project
          query[:opackage] = @target_package
          query[:rev] = action.source_rev if action.source_rev
        else # No target package means diffing the source package against itaction.
          if action.source_rev # Use source rev for diffing (if available)
            query[:orev] = 0
            query[:rev] = action.source_rev
          else # Otherwise generate diff for latest source package revision
               # FIXME: move to Package model
            spkg_rev = Directory.find_hashed(project: action.source_project, package: spkg)['rev']
            query[:orev] = 0
            query[:rev] = spkg_rev
          end
        end
      end
      # run diff
      query[:view] = 'xml' if @view_xml # Request unified diff in full XML view
      query[:withissues] = 1 if @withissues
      BsRequestAction.get_package_diff(path, query)
    end

    def overwrite_target_by_link(spkg)
      # the target is by default the _link target
      # maintenance_release creates new packages instance, but are changing the source only according to the link
      return unless !action.target_package or [:maintenance_incident].include? action.action_type
      data = Xmlhash.parse(ActiveXML.backend.direct_http(URI("/source/#{URI.escape(action.source_project)}/#{URI.escape(spkg)}")))
      e = data['linkinfo']
      return unless e
      @target_project = e["project"]
      @target_package = e["package"]
      return unless @target_project == action.source_project
      # a local link, check if the real source change gets also transported in a seperate action
      action.bs_request.bs_request_actions.each do |a|
        return true if check_action_target(a)
      end if action.bs_request
    end

    # check if the action is the same target
    def check_action_target(other)
      if action.source_project == other.source_project and
          @target_package == other.source_package and
          action.target_project == other.target_project
        return true
      end
    end
  end

  def sourcediff(opts = {})
    d = ActionSourceDiffer.new
    d.action = self
    d.perform(opts)
  end

end
