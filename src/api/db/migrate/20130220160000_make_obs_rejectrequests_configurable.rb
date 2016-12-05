class MakeObsRejectrequestsConfigurable < ActiveRecord::Migration
  def self.up
    a = AttribType.find_by_id(AttribType.find_by_name("OBS:RejectRequests"))
    a.value_count = nil
    a.save!
  end

  def self.down
    a = AttribType.find_by_id(AttribType.find_by_name("OBS:RejectRequests"))
    a.value_count = 1
    a.save!
  end
end
