# frozen_string_literal: true
module Statistics
  class MaintenanceStatistic
    include ActiveModel::Model
    attr_accessor :type, :when, :who, :name, :tracker, :id, :request

    def self.find_by_project(project)
      MaintenanceStatisticsCollection.new(project).build
    end
  end
end
