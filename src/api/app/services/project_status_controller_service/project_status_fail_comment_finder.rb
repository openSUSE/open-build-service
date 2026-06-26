module ProjectStatusControllerService
  class ProjectStatusFailCommentFinder < AttribValuesFinder
    def self.call(packages)
      new(packages, 'OBS', 'ProjectStatusPackageFailComment').attribute_values
    end
  end
end
