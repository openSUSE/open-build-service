# frozen_string_literal: true
class LocalBuildResult
  include ActiveModel::Model
  attr_accessor :repository, :architecture, :code, :state, :details, :summary
end
