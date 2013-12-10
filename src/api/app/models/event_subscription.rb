class EventSubscription < ActiveRecord::Base
  belongs_to :project
  belongs_to :package
  belongs_to :user

  validates :receiver_role, inclusion: { in: [:all, :maintainer, :source_maintainer,
                                              :target_maintainer, :reviewer, :commenter, :creator] }
  validate :only_package_or_project

  def only_package_or_project
    # only one can be set
    errors.add(:package_id, 'is conflicting with project') if self.package && self.project
  end

  def receiver_role
    read_attribute(:receiver_role).to_sym
  end

  def self._get_role_rule(relation, role)
    all_rule = nil
    relation.each do |r|
      if r.receiver_role == role
        return r
      end
      if r.receiver_role == :all
        all_rule = r
      end
    end
    return all_rule
  end

  def self._get_rel(eventtype)
    EventSubscription.where(eventtype: eventtype).where('package_id is null and project_id is null')
  end

  # returns boolean if the eventtype is set for the role
  def self.subscription_value(eventtype, role, user)
    rel = _get_rel(eventtype)

    # check user config first
    rule = _get_role_rule(rel.where(user: user), role)
    return rule.receive if rule

    # now global default
    rule = _get_role_rule(rel.where(user_id: nil), role)
    return rule.receive if rule

    # if nothing set, nothing is set
    false
  end

  def self.update_subscription(eventtype, role, user, value)
    rel = _get_rel(eventtype)
    rule = rel.where(receiver_role: role).first_or_create
    rule.receive = value
    rule.save
  end

  def self.subscription_value(eventtype, role, user)
    # returns yes or no
    rel = EventSubscription.where(eventtype: eventtype).where('package_id is null and project_id is null')

    # check user config first
    rule = rel.where(user: user).first
    return rule.receive if rule
    
    # now global default
    rule = rel.where(user_id: nil).first
    return rule.receive if rule

    # if nothing set, no value
    return nil
  end

  def self.update_subscription(eventtype, role, user, value)
  end

end

