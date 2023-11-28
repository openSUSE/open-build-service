module Backend::Xml
  class Patchinfo::Releasetarget
    include HappyMapper
    include ActiveModel::Model

    attribute :project, String
    attribute :repository, String

    def compare_releasetargets(project)
      project.repositories.each do |r|
        r.release_targets.each do |prt|
          return if repository_matching?(prt.target_repository)
        end
      end
      raise ReleasetargetNotFound, "Release target '#{project}/#{repository}' is not defined " \
                                   "in this project '#{@project.name}'. Please ask your OBS administrator to add it."
    end

    private

    def repository_matching?(repo)
      return false if repo.project.name != project

      return false if repository && (repo.name != repository)

      true
    end
  end
end
