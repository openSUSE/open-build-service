module RequestControllerService
  class RequestWebuiInfo
    def initialize(bs_request, params = {})
      @bs_request = bs_request
      @request = @bs_request.webui_infos(filelimit: params[:diff_limit], tarlimit: params[:diff_limit],
                                         diff_to_superseded: params[:diff_to_superseded])
      @current_user = params[:current_user]
    end

    def id
      @reques['id']
    end

    def number
      @request['number']
    end

    def state
      @request['state'].to_s
    end

    def accept_at
      @request['accept_at']
    end

    def creator
      @request['creator']
    end

    def author?
      creator == current_user
    end

    def superseded_by
      @request['superseded_by']
    end

    def superseding
      @request['superseding']
    end

    def target_maintainer?
      @request['is_target_maintainer']
    end

    def my_open_reviews
      @request['my_open_reviews']
    end

    def other_open_reviews
      @request['other_open_reviews']
    end

    def can_add_reviews?
      state.in?(['new', 'review']) && (author? || target_maintainer? || my_open_reviews.present?) && !current_user.is_nobody?
    end

    def can_handle_request?
      state.in?(['new', 'review', 'declined']) && (target_maintainer? || author?) && !current_user.is_nobody?
    end

    def history
      @bs_request.history_elements.includes(:user)
    end

    def actions
      @request['actions']
    end

    def projects
      actions.map { |action| action[:tprj] }.uniq
    end

    # print a hint that the diff is not fully shown (this only needs to be verified for submit actions)
    def not_full_diff?
      BsRequest.truncated_diffs?(@request)
    end

    def maintainer_of_projects?
      projects.any? { |project| Project.find_by_name(project).user_has_role?(current_user, maintainer_role) }
    end

    def show_project_maintainer_hint?
      (!package_maintainers.empty? && !package_maintainers.include?(current_user) && maintainer_of_projects?)
    end

    def package_maintainers
      # retrieve a list of all package maintainers that are assigned to at least one target package
      target_package_maintainers || []
    end

    private

    attr_reader :current_user

    def maintainer_role
      Role.find_by_title('maintainer')
    end

    def target_package_maintainers
      new_actions = actions.uniq { |action| action[:tpkg] }
      new_actions.flat_map { |action| Package.find_by_project_and_name(action[:tprj], action[:tpkg]).try(:maintainers) }.compact.uniq
    end
  end
end
