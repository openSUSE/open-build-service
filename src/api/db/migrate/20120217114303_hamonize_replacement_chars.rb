class HamonizeReplacementChars < ActiveRecord::Migration
  def self.up
    IssueTracker.find(:all).each do |t|
      t.label = t.label.gsub("%s", "@@@")
      t.save
    end
  end

  def self.down
    IssueTracker.find(:all).each do |t|
      t.label = t.label.gsub("@@@", "%s")
      t.save
    end
  end
end
