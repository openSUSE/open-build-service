class SetDefaultSiteConfigs < ActiveRecord::Migration
  def self.up
    SiteConfig.find_or_create_by_title_and_description(:title => "Open Build Service", :description => <<-EOT
      <p class="description">
        The <%= link_to 'Open Build Service (OBS)', 'http://openbuildservice.org', :title => 'OBS Project Page' %>
        is an open and complete distribution development platform that provides a transparent infrastructure for development of Linux distributions, used by openSUSE, MeeGo and other distributions.
        Supporting also Fedora, Debian, Ubuntu, RedHat and other Linux distributions.
      </p>
      <p class="description">
        The OBS is developed under the umbrella of the <%= link_to 'openSUSE project', 'http://www.opensuse.org', :title => 'openSUSE project page' %>. Please find further informations on the <%= link_to 'openSUSE Project wiki pages', 'http://wiki.opensuse.org/openSUSE:Build_Service', :title => 'OBS wiki pages' %>.
      </p>

      <p class="description">
        The Open Build Service developer team is greeting you. In case you use your OBS productive in your facility, please do us a favor and add yourself at <%= link_to 'this wiki page', 'http://wiki.opensuse.org/openSUSE:Build_Service_installations' %>. Have fun and fast build times!
      </p>
    EOT
    )
  end

  def self.down
    SiteConfig.find_by_title("Open Build Service").delete
  end
end

