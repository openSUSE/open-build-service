
class AlterIssueTrackers < ActiveRecord::Migration
  def self.up
    # Instead of identyfing issue trackers by a set of acronyms, use a regex.
    # This allows to match issues like 'CVE-2011-1234' and 'bnc#1234'.
    change_table :issue_trackers do |t|
      t.column :kind, "ENUM('bugzilla', 'cve', 'fate', 'trac', 'launchpad', 'sourceforge')", :after => :name
      t.string :description, :after => :kind
      t.string :regex, :null => false
      # Can't use ':type', it's a Ruby reserved word that doesn't produce errors but silently breaks:
    end

    # Acronyms aren't helpful anymore, the API will provide a route "get me the issue tracker for bug 'bnc#1234'"
    drop_table :issue_tracker_acronyms

    # Clean up table, so that we can populate it correctly
    execute "DELETE FROM issue_trackers;"
    it = IssueTracker.find_or_create_by_name('boost', :description => 'Boost Trac', :kind => 'trac', :regex => 'boost#(\d+)', :url => 'https://svn.boost.org/trac/boost/', :show_url => 'https://svn.boost.org/trac/boost/ticket/@@@')
    it = IssueTracker.find_or_create_by_name('bco', :description => 'Clutter Project Bugzilla', :kind => 'bugzilla', :regex => 'bco#(\d+)', :url => 'http://bugzilla.clutter-project.org/', :show_url => 'http://bugzilla.clutter-project.org/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('RT', :description => 'CPAN Bugs', :kind => 'other', :regex => 'RT#(\d+)', :url => 'https://rt.cpan.org/', :show_url => 'http://rt.cpan.org/Public/Bug/Display.html?id=@@@')
    it = IssueTracker.find_or_create_by_name('cve', :description => 'CVE Numbers', :kind => 'cve', :regex => 'CVE-\d{4,4}-\d{4,4}', :url => 'http://www.cvedetails.com/', :show_url => 'http://www.cvedetails.com/cve/@@@')
    it = IssueTracker.find_or_create_by_name('deb', :description => 'Debian Bugzilla', :kind => 'bugzilla', :regex => 'deb#(\d+)', :url => 'http://bugs.debian.org/', :show_url => 'http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=@@@')
    it = IssueTracker.find_or_create_by_name('fdo', :description => 'Freedesktop.org Bugzilla', :kind => 'bugzilla', :regex => 'fdo#(\d+)', :url => 'https://bugs.freedesktop.org/', :show_url => 'https://bugs.freedesktop.org/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('GCC', :description => 'GCC Bugzilla', :kind => 'bugzilla', :regex => 'GCC#(\d+)', :url => 'http://gcc.gnu.org/bugzilla/', :show_url => 'http://gcc.gnu.org/bugzilla/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('bgo', :description => 'Gnome Bugzilla', :kind => 'bugzilla', :regex => 'bgo#(\d+)', :url => 'https://bugzilla.gnome.org/', :show_url => 'https://bugzilla.gnome.org/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('bio', :description => 'Icculus.org Bugzilla', :kind => 'bugzilla', :regex => 'bio#(\d+)', :url => 'https://bugzilla.icculus.org/', :show_url => 'https://bugzilla.icculus.org/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('bko', :description => 'Kernel.org Bugzilla', :kind => 'bugzilla', :regex => '(Kernel|K|bko)#(\d+)', :url => 'https://bugzilla.kernel.org/', :show_url => 'https://bugzilla.kernel.org/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('kde', :description => 'KDE Bugzilla', :kind => 'bugzilla', :regex => 'kde#(\d+)', :url => 'https://bugs.kde.org/', :show_url => 'https://bugs.kde.org/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('lp', :description => 'Launchpad.net Bugtracker', :kind => 'launchpad', :regex => 'b?lp#(\d+)', :url => 'https://bugs.launchpad.net/bugs/', :show_url => 'https://bugs.launchpad.net/bugs/@@@')
    it = IssueTracker.find_or_create_by_name('Meego', :description => 'Meego Bugs', :kind => 'bugzilla', :regex => 'Meego#(\d+)', :url => 'https://bugs.meego.com/', :show_url => 'https://bugs.meego.com/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('bmo', :description => 'Mozilla Bugzilla', :kind => 'bugzilla', :regex => 'bmo#(\d+)', :url => 'https://bugzilla.mozilla.org/', :show_url => 'https://bugzilla.mozilla.org/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('bnc', :description => 'Novell Bugzilla', :kind => 'bugzilla', :regex => 'bnc#(\d+)', :url => 'https://bugzilla.novell.com/', :show_url => 'https://bugzilla.novell.com/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('ITS', :description => 'OpenLDAP Issue Tracker', :kind => 'other', :regex => 'ITS#(\d+)', :url => 'http://www.openldap.org/its/', :show_url => 'http://www.openldap.org/its/index.cgi/Contrib?id=@@@')
    it = IssueTracker.find_or_create_by_name('i', :description => 'OpenOffice.org Bugzilla', :kind => 'bugzilla', :regex => 'i#(\d+)', :url => 'http://openoffice.org/bugzilla/', :show_url => 'http://openoffice.org/bugzilla/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('fate', :description => 'openSUSE Feature Database', :kind => 'fate', :regex => '[Ff]ate#(\d+)', :url => 'https://features.opensuse.org/', :show_url => 'https://features.opensuse.org/@@@')
    it = IssueTracker.find_or_create_by_name('rh', :description => 'RedHat Bugzilla', :kind => 'bugzilla', :regex => 'rh#(\d+)', :url => 'https://bugzilla.redhat.com/', :show_url => 'https://bugzilla.redhat.com/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('bso', :description => 'Samba Bugzilla', :kind => 'bugzilla', :regex => 'bso#(\d+)', :url => 'https://bugzilla.samba.org/', :show_url => 'https://bugzilla.samba.org/show_bug.cgi?id=@@@')
    it = IssueTracker.find_or_create_by_name('sf', :description => 'SourceForge.net Tracker', :kind => 'sourceforge', :regex => 'sf#(\d+)', :url => 'http://sf.net/support/', :show_url => 'http://sf.net/support/tracker.php?aid=@@@')
    it = IssueTracker.find_or_create_by_name('Xamarin', :description => 'Xamarin Bugzilla', :kind => 'bugzilla', :regex => 'Xamarin#(\d+)', :url => 'http://bugzilla.xamarin.com/index.cgi', :show_url => 'http://bugzilla.xamarin.com/show_bug.cgi?id=@@@')
  end

  def self.down
    create_table :issue_tracker_acronyms do |t|
      t.integer :issue_tracker_id
      t.string :name, :null => false
      t.index :name
    end

    change_table :issue_trackers do |t|
      t.remove :description
      t.remove :regex
      t.remove :kind
    end
  end
end
