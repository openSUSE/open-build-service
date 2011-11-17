class EnhanceIssueTrackerRegexen < ActiveRecord::Migration
  def self.up
    # Update Bugzilla, Fate and Trac issue trackers. For example, only the
    # number part of 'bnc#123456' should be send to the upstream issue tracker, it doesn't
    # care for 'bnc'. This holds true for most other issue trackers, with the exception of CVE.
    # For CVEs, the whole number can be send upstream (e.g 'CVE-2011-1234').

    # This is easily fixed by only returning the number part in a RegEx capture group instead of
    # the whole match. This implies that a regexp should include at most one capture group

    trackers_regexen = {
      :boost => 'boost#(\d+)',
      :bco => 'bco#(\d+)',
      :RT => 'RT#(\d+)',
      :deb => 'deb#(\d+)',
      :fdo => 'fdo#(\d+)',
      :GCC => 'GCC#(\d+)',
      :bgo => 'bgo#(\d+)',
      :bio => 'bio#(\d+)',
      :bko => '(Kernel|K|bko)#(\d+)',
      :kde => 'kde#(\d+)',
      :lp => 'b?lp#(\d+)',
      :Meego => 'Meego#(\d+)',
      :bmo => 'bmo#(\d+)',
      :bnc => 'bnc#(\d+)',
      :ITS => 'ITS#(\d+)',
      :i => 'i#(\d+)',
      :fate => '[Ff]ate#(\d+)',
      :rh => 'rh#(\d+)',
      :bso => 'bso#(\d+)',
      :sf => 'sf#(\d+)',
      :Xamarin => 'Xamarin#(\d+)'
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
      :boost => 'boost#\d+',
      :bco => 'bco#\d+',
      :RT => 'RT#\d+',
      :deb => 'deb#\d+',
      :fdo => 'fdo#\d+',
      :GCC => 'GCC#\d+',
      :bgo => 'bgo#\d+',
      :bio => 'bio#\d+',
      :bko => '(Kernel|K|bko)#\d+',
      :kde => 'kde#\d+',
      :lp => 'b?lp#\d+',
      :Meego => 'Meego#\d+',
      :bmo => 'bmo#\d+',
      :bnc => 'bnc#\d+',
      :ITS => 'ITS#\d+',
      :i => 'i#\d+',
      :fate => '[Ff]ate#\d+',
      :rh => 'rh#\d+',
      :bso => 'bso#\d+',
      :sf => 'sf#\d+',
      :Xamarin => 'Xamarin#\d+'
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

