class MaintainersAndReviewersFinder
  attr_reader :package, :project, :relation, :review

  def initialize(review, relation: Relationship.includes(:user, :group))
    @relation = relation
    @review = review
    @package = review.package
    @project = review&.package&.project
  end

  def for_project
    extract_reviewers(relation.for_project(project))
  end

  def for_package
    extract_reviewers(relation.for_package(package))
  end

  private

  def extract_reviewers(relationships)
    relationships.for_maintainer_and_reviewer_roles
                 .map { |relation| relation.user || relation.group.users }
                 .flatten.uniq
  end
end
