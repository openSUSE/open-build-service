class EventSubscription < ActiveRecord::Base
  belongs_to :user, inverse_of: :event_subscriptions

  validates :receiver_role, inclusion: { in: [:all, :maintainer, :source_maintainer,
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
  def self.subscription_value(eventtype, role, user)
    rel = _get_rel(eventtype)

    if user
      # check user config first
      rule = _get_role_rule(rel.where(user: user), role)
      return rule.receive if rule
    end

    # now global default
    rule = _get_role_rule(rel.where(user_id: nil), role)
    return rule.receive if rule

    # if nothing set, nothing is set
    false
  end

  def self.update_subscription(eventtype, role, user, value)
    rel = _get_rel(eventtype)
    if user
      rel = rel.where(user: user)
    else
      rel = rel.where(user_id: nil)
    end
    rule = rel.where(receiver_role: role).first_or_create
    rule.receive = value
    rule.save
  end

end

