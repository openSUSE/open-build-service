class CommentSnippetPolicy < ApplicationPolicy
  def initialize(user, record)
    super(user, record, user_optional: true)
  end

  def create
    update?
  end

  def destroy?
    update?
  end

  def update?
    return false if user.blank? || user.is_nobody?

    user == record.user
  end
end
