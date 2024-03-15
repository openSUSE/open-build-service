class SourcediffComponent < ApplicationComponent
  attr_accessor :bs_request, :action, :refresh, :commentable, :source_package, :target_package

  delegate :diff_label, to: :helpers
  delegate :diff_data, to: :helpers

  def initialize(bs_request:, action:, commentable:, source_package:, target_package:)
    super

    @bs_request = bs_request
    @action = action
    @commentable = commentable
    @source_package = source_package
    @target_package = target_package
  end
end
