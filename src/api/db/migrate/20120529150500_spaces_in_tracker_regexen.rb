class SpacesInTrackerRegexen < ActiveRecord::Migration
  def self.up
    # Update Bugzilla and Fate issue tracker, i.e. allow spaces like in 'bnc #1234'
    # which was considered ok in Autobuild and is unlikely to be fixed for old sources soon:
    trackers_regexen = {
      bnc:  '(?:bnc|BNC)\s*[#:]\s*(\d+)',
      fate: '[Ff]ate\s+#\s+(\d+)'
    }
    trackers_regexen.each do |tracker, regex|
      it = IssueTracker.find_by_name(tracker.to_s)
      if it
        it.regex = regex
        it.save!
      end
    end
  end

  def self.down
    # Undo the above
    trackers_regexen = {
      bnc:  'bnc#(\d+)',
      fate: '[Ff]ate#(\d+)'
    }
    trackers_regexen.each do |tracker, regex|
      it = IssueTracker.find_by_name(tracker.to_s)
      if it
        it.regex = regex
        it.save!
      end
    end
  end
end
