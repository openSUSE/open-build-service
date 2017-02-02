module Statistics
  class MaintenanceStatistic
    include ActiveModel::Model
    attr_accessor :type, :when, :who, :name, :tracker, :id

    def self.find_by_project(project)
      MaintenanceStatisticsCollection.new(project).build
    end
  end
end
