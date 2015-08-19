class FixEmptyComments2 < ActiveRecord::Migration
  def up
    ActiveRecord::Base.record_timestamps = false
    BsRequestHistory.all.each do |r|
      next if r.comment.blank?
      if r.comment.strip == '--- !ruby/hash:Xmlhash::XMLHash {}'
        r.comment = nil
        r.save
      end
    end
  end

  def down
  end
end
