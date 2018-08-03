require 'api_exception'

class Owner
  def self.attribute_names
    [:rootproject, :project, :package, :filter, :users, :groups]
  end

  include ActiveModel::Model
  attr_accessor(*attribute_names)

  def user_or_group?
    users.present? || groups.present?
  end

  def to_hash
    # The same implemented as one-liner, but code climate doesn't like
    # Hash[*(Owner.attribute_names.map {|a| [a, send(a)] }.select {|a| !a.last.nil? }.flatten(1))]
    hash = {}
    Owner.attribute_names.map do |a|
      unless (value = send(a)).nil?
        hash[a] = value
      end
    end
    hash
  end
end
