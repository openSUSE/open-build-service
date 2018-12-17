class LocalBuildResult
  include ActiveModel::Model
  attr_accessor :repository, :architecture, :code, :state, :details, :summary, :is_repository_in_db
end
