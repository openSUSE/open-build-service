class SetDefaultConfigurations < ActiveRecord::Migration
  def self.up
    Configuration.destroy_all
    Configuration.create(:title => "Open Build Service", :description => <<-EOT
  <p class="description">
    The <a href="http://openbuildservice.org">Open Build Service (OBS)</a>
    is an open and complete distribution development platform that provides a transparent infrastructure for development of Linux distributions, used by openSUSE, MeeGo and other distributions.
    Supporting also Fedora, Debian, Ubuntu, RedHat and other Linux distributions.
  </p>
  <p class="description">
    The OBS is developed under the umbrella of the <a href="http://www.opensuse.org">openSUSE project</a>. Please find further informations on the <a href="http://wiki.opensuse.org/openSUSE:Build_Service">openSUSE Project wiki pages</a>.
  </p>

  <p class="description">
    The Open Build Service developer team is greeting you. In case you use your OBS productive in your facility, please do us a favor and add yourself at <a href="http://wiki.opensuse.org/openSUSE:Build_Service_installations">this wiki page</a>. Have fun and fast build times!
  </p>
    EOT
    )
  end

  def self.down
    Configuration.destroy_all
  end
end

