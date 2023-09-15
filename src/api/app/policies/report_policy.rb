class ReportPolicy < ApplicationPolicy
  attr_reader :user, :record, :reportable

  def initialize(user, record)
    super(user, record)

    @user = user
    @record = record
    @reportable = record.try(:reportable)
  end

  def index?
    user.is_admin?
  end

  def show?
    user.is_admin? || record.user == user
  end

  def create?
    return false unless Flipper.enabled?(:content_moderation, user)

    # We don't want reports twice...
    return false if user.submitted_reports.where(reportable: reportable).any?

    # We don't want reports for things you can change yourself...
    case reportable.class.name
    when 'Package'
      !PackagePolicy.new(user, reportable).update?
    when 'Project'
      !ProjectPolicy.new(user, reportable).update?
    when 'Comment'
      !CommentPolicy.new(user, reportable).update?
    when 'User'
      !UserPolicy.new(user, reportable).update?
    end
  end

  def destroy?
    return false unless Flipper.enabled?(:content_moderation, user)

    user.is_admin? || record.user == user
  end
end
