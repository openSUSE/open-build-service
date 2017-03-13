class Project
  class CleanupBeforeDestroyCommand
    attr_reader :project

    def initialize(project)
      @project = project
    end

    def run
      CacheLine.cleanup_project(project.name)

      # find linking projects
      cleanup_linking_projects

      # find linking repositories
      cleanup_linking_repos

      # find linking target repositories
      cleanup_linking_targets

      # deleting local devel packages
      project.packages.each do |pkg|
        if pkg.develpackage_id
          pkg.develpackage_id = nil
          pkg.save
        end
      end

      revoke_requests # Revoke all requests that have this project as source/target
      cleanup_packages # Deletes packages (only in DB)
      delete_on_backend # Deletes the project in the backend
    end

    private

    def cleanup_linking_projects
      # replace links to this project with links to the "deleted" project
      LinkedProject.transaction do
        LinkedProject.where(linked_db_project: self).each do |lp|
          id = lp.db_project_id
          lp.destroy
          Rails.cache.delete("xml_project_#{id}")
        end
      end
    end

    def cleanup_linking_repos
      # replace links to this project repositories with links to the "deleted" repository
      find_repos(:linking_repositories) do |link_rep|
        link_rep.path_elements.includes(:link).each do |pe|
          next unless Repository.find(pe.repository_id).db_project_id == id
          if link_rep.path_elements.find_by_repository_id Repository.deleted_instance
            # repository has already a path to deleted repo
            pe.destroy
          else
            pe.link = Repository.deleted_instance
            pe.save
          end
          # update backend
          link_rep.project.write_to_backend
        end
      end
    end

    def cleanup_linking_targets
      # replace links to this projects with links to the "deleted" project
      find_repos(:linking_target_repositories) do |link_rep|
        link_rep.release_targets.includes(:target_repository).each do |rt|
          next unless Repository.find(rt.repository_id).db_project_id == project.id
          rt.target_repository = Repository.deleted_instance
          rt.save
          # update backend
          link_rep.project.write_to_backend
        end
      end
    end

    def revoke_requests
      # Find open requests involving self and:
      # - revoke them if self is source
      # - decline if self is target
      # Note: As requests are a backend matter, it's pointless to include them into the transaction below
      open_requests_with_project_as_source_or_target.each do |request|
        Rails.logger.debug "#{self.class} #{project.name} doing revoke_requests with #{project.commit_opts.inspect}"
        # Don't alter the request that is the trigger of this revoke_requests run
        next if request == project.commit_opts[:request]

        request.bs_request_actions.each do |action|
          if action.source_project == project.name
            begin
              request.change_state({newstate: 'revoked', comment: "The source project '#{project.name}' has been removed"})
            rescue PostRequestNoPermission
              Rails.logger.debug "#{User.current.login} tried to revoke request #{request.number} but had no permissions"
            end
            break
          end
          if action.target_project == project.name
            begin
              request.change_state({newstate: 'declined', comment: "The target project '#{project.name}' has been removed"})
            rescue PostRequestNoPermission
              Rails.logger.debug "#{User.current.login} tried to decline request #{request.number} but had no permissions"
            end
            break
          end
        end
      end

      # Find open requests which have a review involving this project (or it's packages) and remove those reviews
      # but leave the requests otherwise untouched.
      open_requests_with_by_project_review.each do |request|
        # Don't alter the request that is the trigger of this revoke_requests run
        next if request == project.commit_opts[:request]

        request.obsolete_reviews(by_project: project.name)
      end
    end

    def open_requests_with_project_as_source_or_target
      # Includes also requests for packages contained in this project
      rel = BsRequest.where(state: [:new, :review, :declined]).joins(:bs_request_actions)
      rel = rel.where('bs_request_actions.source_project = ? or bs_request_actions.target_project = ?', project.name, project.name)
      BsRequest.where(id: rel.pluck('bs_requests.id'))
    end

    def open_requests_with_by_project_review
      # Includes also by_package reviews for packages contained in this project
      rel = BsRequest.where(state: [:new, :review])
      rel = rel.joins(:reviews).where("reviews.state = 'new' and reviews.by_project = ? ", project.name)
      BsRequest.where(id: rel.pluck('bs_requests.id'))
    end

    # The backend takes care of deleting the packages,
    # when we delete ourself. No need to delete packages
    # individually on backend
    def cleanup_packages
      project.packages.each do |package|
        package.commit_opts = { no_backend_write: 1,
                                project_destroy_transaction: 1, request: project.commit_opts[:request]
                               }
        package.destroy
      end
    end

    def delete_on_backend
      if CONFIG['global_write_through'] && !project.commit_opts[:no_backend_write]
        path = project.source_path
        h = {user: User.current.login, comment: project.commit_opts[:comment]}
        h[:requestid] = project.commit_opts[:request].number if project.commit_opts[:request]
        path << Suse::Backend.build_query_from_hash(h, [:user, :comment, :requestid])
        begin
          Suse::Backend.delete path
        rescue ActiveXML::Transport::NotFoundError
          # ignore this error, backend was out of sync
          Rails.logger.warn("Project #{project.name} was already missing on backend on removal")
        end
        Rails.logger.tagged('backend_sync') { Rails.logger.warn "Deleted Project #{project.name}" }
      elsif project.commit_opts[:no_backend_write]
        Rails.logger.tagged('backend_sync') { Rails.logger.warn "Not deleting Project #{project.name}, backend_write is off " }
      else
        Rails.logger.tagged('backend_sync') { Rails.logger.warn "Not deleting Project #{project.name}, global_write_through is off" }
      end

      project.commit_opts = {}
      true
    end

    def find_repos(sym)
      project.repositories.each do |repo|
        repo.send(sym).each do |lrep|
          yield lrep
        end
      end
    end
  end
end
