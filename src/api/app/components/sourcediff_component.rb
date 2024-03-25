class SourcediffComponent < ApplicationComponent
  attr_accessor :bs_request, :action, :refresh, :commentable, :source_package, :target_package

  delegate :diff_label, to: :helpers
  delegate :diff_data, to: :helpers

  def initialize(bs_request:, action:, commentable:, source_package:, target_package:)
    super

    # Nomes es fa servir per extreure el numero de la request
    @bs_request = bs_request
    # @action es bs_request.bs_request_actions.first quan ve per #changes
    # @action es bs_request.bs_request_actions.find(params['id']) quan ve per #request_action_changes
    @action = action
    @commentable = commentable
    @source_package = source_package
    @target_package = target_package
  end
end
