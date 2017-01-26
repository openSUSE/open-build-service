class LocalBuildResult
  include ActiveModel::Model
  attr_accessor :repository, :architecture, :code, :state, :details
end
