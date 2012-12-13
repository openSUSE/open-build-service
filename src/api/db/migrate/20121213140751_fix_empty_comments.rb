class FixEmptyComments < ActiveRecord::Migration
  def up
    Review.all.each do |r|
      next unless r.reason
      if r.reason.strip == '--- !ruby/hash:Xmlhash::XMLHash {}'
        r.reason = nil
        r.save
      end
    end
  end

  def down
  end
end
