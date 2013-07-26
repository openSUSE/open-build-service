# just key:value for things to be stored about the running backend
# and that are not configuration
class BackendInfo < ActiveRecord::Base

  def self.lastevents_nr=(nr)
    v = BackendInfo.find_or_initialize_by(key: 'lastevents_nr')
    v.value = nr.to_s
    v.save
  end

  def self.lastevents_nr
    nr = BackendInfo.where(key: 'lastevents_nr').pluck(:value)
    return 0 if nr.empty?
    Integer(nr[0])
  end
end
