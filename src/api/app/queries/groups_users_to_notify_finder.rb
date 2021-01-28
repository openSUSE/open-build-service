class GroupsUsersToNotifyFinder
  attr_reader :relation

  def initialize(relation = GroupUsers.all)
    @relation = relation
  end

  def call
    relation.where(email: true)
  end
end
