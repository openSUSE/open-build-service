# just key:value for things to be stored about the running backend
# and that are not configuration
class BackendInfo < ActiveRecord::Base

  def self.set_value(key, value)
    v = BackendInfo.find_or_initialize_by(key: key)
    v.value = value
    v.save!
  end

  def self.lastnotification_nr=(nr)
    self.set_value('lastnotification_nr', nr.to_s)
  end

  def self.get_value(key)
    BackendInfo.where(key: key).pluck(:value)
  end

  def self.get_integer(key)
    nr = self.get_value(key)
    return 0 if nr.empty?
    Integer(nr[0])
  end

  def self.lastnotification_nr
    self.get_integer('lastnotification_nr')
  end

end
