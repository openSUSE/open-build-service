class BsRequestAction
  module Differ
    class QueryBuilder
      include ActiveModel::Model
      attr_accessor :target_project, :target_package, :action, :source_package

      def build
        # the target is by default the _link target
        # maintenance_release creates new packages instance, but are changing the source only according to the link
        provided_in_other_action = check_for_local_linked_packages(source_package)
        # fallback name as last resort
        self.target_package ||= action.source_package

        # maintenance incidents shall show the final result after release
        self.target_project = action.target_releaseproject if action.target_releaseproject

        # maintenance release targets will have a base link
        tprj = Project.get_by_name(target_project)
        if tprj && tprj.maintenance_release?
          tpkg = tprj.find_package(target_package.gsub(/\.[^.]*$/, ''))
          if tpkg
            if tpkg.project.maintenance_release? && tpkg.local_link?
              # use package container from former incident update
              self.target_package = tpkg.linkinfo['package']
            else
              self.target_project = tprj.name
              self.target_package = tpkg.name
            end
          end
        end

        tpkg = Package.get_by_project_and_name(target_project, target_package) if Package.exists_by_project_and_name(target_project, target_package)

        query = {}

        if !provided_in_other_action && !action.updatelink
          # do show the same diff multiple times, so just diff unexpanded so we see possible link changes instead
          # also get sure that the request would not modify the link in the target
          query[:expand] = 1
        end

        if tpkg
          query[:oproject] = target_project
          query[:opackage] = target_package
          query[:rev] = action.source_rev if action.source_rev
        elsif action.source_rev # Use source rev for diffing (if available)
          # No target package means diffing the source package against itself.
          query[:orev] = 0
          query[:rev] = action.source_rev
        else # Otherwise generate diff for latest source package revision
          # FIXME: move to Package model
          spkg_rev = Directory.hashed(project: action.source_project, package: source_package)['rev']
          query[:orev] = 0
          query[:rev] = spkg_rev
        end
        query
      end

      private

      def check_for_local_linked_packages(spkg)
        # the target is by default the _link target
        # maintenance_release creates new packages instance, but are changing the source only according to the link
        return if action.target_package && action.action_type == :maintenance_incident

        begin
          data = Xmlhash.parse(Backend::Api::Sources::Package.files(action.source_project, spkg))
        rescue Backend::Error
          return
        end
        linkinfo = data['linkinfo']
        return unless linkinfo

        self.target_project ||= linkinfo['project']
        self.target_package ||= linkinfo['package']
        return unless linkinfo['project'] == action.source_project

        # a local link, check if the real source change gets also transported in a separate action
        action.bs_request.bs_request_actions.any? { |a| check_action_target(a, linkinfo['package']) } if action.bs_request
      end

      # check if the action is the same target
      def check_action_target(other, linked_package_name)
        action.source_project == other.source_project &&
          linked_package_name == other.source_package &&
          action.target_project == other.target_project
      end
    end
  end
end
