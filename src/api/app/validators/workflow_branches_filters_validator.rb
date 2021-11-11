class WorkflowBranchesFiltersValidator < ActiveModel::Validator
  def validate(record)
    @workflow = record
    validate_branch_matches_branches_filter
  end

  private

  def validate_branch_matches_branches_filter
    return unless @workflow.supported_filters.key?(:branches)

    branches_only = @workflow.filters[:branches].fetch(:only, [])
    branches_ignore = @workflow.filters[:branches].fetch(:ignore, [])

    return if branches_only.present? && branches_only.include?(@workflow.scm_webhook.payload[:target_branch])
    return if branches_ignore.present? && branches_ignore.exclude?(@workflow.scm_webhook.payload[:target_branch])

    @workflow.errors.add(:base, "target branch doesn't match the branches filter")
  end
end
