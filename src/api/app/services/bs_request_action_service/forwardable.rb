module BsRequestActionService
  class Forwardable
    def initialize(bs_request_action)
      @bs_request_action = bs_request_action
    end

    def create(fwd_target_prj, fwd_target_pkg)
      previous_action = @bs_request_action
      rev = Directory.hashed(project: previous_action.target_project,
                             package: previous_action.target_package)['rev']

      BsRequestAction.new(source_project: previous_action.target_project,
                          source_package: previous_action.target_package,
                          source_rev: rev,
                          target_project: fwd_target_prj,
                          target_package: fwd_target_pkg,
                          type: previous_action.type)
    end

    def possible_targets
      target_package = @bs_request_action.target_package_object
      forwarding_targets = target_package.developed_packages
      linkinfo = target_package.linkinfo

      return forwarding_targets unless linkinfo

      unless forwarding_targets.any? { |t| t.name == linkinfo['package'] && t.project.name == linkinfo['project'] }
        forwarding_targets.append(Package.find_by_project_and_name(linkinfo['project'], linkinfo['package']))
      end
      forwarding_targets
    end
  end
end
