# frozen_string_literal: true
class AddGithubIssueParser < ActiveRecord::Migration[4.2]
  def self.up
    # rubocop:disable Metrics/LineLength
    execute "alter table issue_trackers modify column kind enum('other','bugzilla','cve','fate','trac','launchpad','sourceforge', 'github') not null;"

    IssueTracker.where(name: 'obs').first_or_create(description: 'OBS GitHub Issues', kind: 'github', regex: 'obs#(\d+)', url: 'https://api.github.com/repos/openSUSE/open-build-service/issues', label: 'obs#@@@', show_url: 'https://github.com/openSUSE/open-build-service/issues/@@@')
    IssueTracker.where(name: 'build').first_or_create(description: 'OBS build script Issues', kind: 'github', regex: 'build#(\d+)', url: 'https://api.github.com/repos/openSUSE/obs-build/issues', label: 'build#@@@', show_url: 'https://github.com/openSUSE/obs-build/issues/@@@')
    IssueTracker.where(name: 'osc').first_or_create(description: 'OBS CLI Issues', kind: 'github', regex: 'osc#(\d+)', url: 'https://api.github.com/repos/openSUSE/osc/issues', label: 'osc#@@@', show_url: 'https://github.com/openSUSE/osc/issues/@@@')
    # rubocop:enable Metrics/LineLength
  end

  def self.down
    i = IssueTracker.where(name: 'obs').first
    i.destroy if i
    i = IssueTracker.where(name: 'build').first
    i.destroy if i
    i = IssueTracker.where(name: 'osc').first
    i.destroy if i

    execute "alter table issue_trackers modify column kind enum('other','bugzilla','cve','fate','trac','launchpad','sourceforge') not null;"
  end
end
