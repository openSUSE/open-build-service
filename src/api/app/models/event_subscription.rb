class EventSubscription < ActiveRecord::Base
  belongs_to :user, inverse_of: :event_subscriptions
  belongs_to :group, inverse_of: :event_subscriptions

  validates :receiver_role, inclusion: { in: [:all, :maintainer, :bugowner, :source_maintainer,
                                              :target_maintainer, :reviewer, :commenter, :creator] }

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
    EventSubscription.where(eventtype: eventtype)
  end

  # returns boolean if the eventtype is set for the role
  def self.subscription_value(eventtype, role, subscriber)
    rel = _get_rel(eventtype)

    # check user or group config first
    if subscriber.kind_of? User
      rule = _get_role_rule(rel.where(user: subscriber), role)
      return rule.receive if rule
    elsif subscriber.kind_of? Group
      rule = _get_role_rule(rel.where(group: subscriber), role)
      return rule.receive if rule
    end

    # now global default
    rule = _get_role_rule(rel.where(user_id: nil, group_id: nil), role)
    return rule.receive if rule

    # if nothing set, nothing is set
    false
  end

  def self.update_subscription(eventtype, role, subscriber, value)
    rel = _get_rel(eventtype)
    if subscriber.kind_of? User
      rel = rel.where(user: subscriber)
    elsif subscriber.kind_of? Group
      rel = rel.where(group: subscriber)
    else
      rel = rel.where(user_id: nil, group_id: nil)
    end
    rule = rel.where(receiver_role: role).first_or_create
    rule.receive = value
    rule.save
  end

end

