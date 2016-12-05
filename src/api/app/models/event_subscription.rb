class EventSubscription < ApplicationRecord
  belongs_to :user, inverse_of: :event_subscriptions
  belongs_to :group, inverse_of: :event_subscriptions

  validates :receiver_role, inclusion: { in: [:all, :maintainer, :bugowner, :reader, :source_maintainer,
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
    all_rule
  end

  def self._get_rel(eventtype)
    EventSubscription.where(eventtype: eventtype)
  end

  # returns boolean if the eventtype is set for the role
  def self.subscription_value(eventtype, role, subscriber)
    rel = _get_rel(eventtype)

    # check user or group config first
    if subscriber
      rule = _get_role_rule(filter_relationships(rel, subscriber), role)
      return rule.receive if rule
    end

    # now global default
    rule = _get_role_rule(rel.where(user_id: nil, group_id: nil), role)
    return rule.receive if rule

    # if nothing set, nothing is set. Thank you captain obvious!
    false
  end

  def self.update_subscription(eventtype, role, subscriber, value)
    rel = _get_rel(eventtype)
    rel = filter_relationships(rel, subscriber)
    rule = rel.where(receiver_role: role).first_or_create
    rule.receive = value
    rule.save
  end

  def self.filter_relationships(rel, obj)
    if obj.kind_of? User
      return rel.where(user: obj)
    elsif obj.kind_of? Group
      return rel.where(group: obj)
    elsif obj.nil?
      return rel.where(user_id: nil, group_id: nil)
    end

    raise "Unable to filter by #{obj.class}"
  end
end
