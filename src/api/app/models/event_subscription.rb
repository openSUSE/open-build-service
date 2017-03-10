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
    return rel.where(user: obj) if obj.kind_of? User
    return rel.where(group: obj) if obj.kind_of? Group
    return rel.where(user_id: nil, group_id: nil) if obj.nil?

    raise "Unable to filter by #{obj.class}"
  end
end

# == Schema Information
#
# Table name: event_subscriptions
#
#  id            :integer          not null, primary key
#  eventtype     :string(255)      not null
#  receiver_role :string(255)      not null
#  user_id       :integer
#  created_at    :datetime
#  updated_at    :datetime
#  receive       :boolean          default("1"), not null
#  group_id      :integer
#
# Indexes
#
#  index_event_subscriptions_on_group_id  (group_id)
#  index_event_subscriptions_on_user_id   (user_id)
#
