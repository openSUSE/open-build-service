# frozen_string_literal: true
class AddLinuxFoundationIssueTracker < ActiveRecord::Migration[5.1]
  def up
    IssueTracker.where(name: 'lf').first_or_create(description: 'Linux Foundation Bugzilla',
                                                   kind: 'bugzilla',
                                                   regex: 'lf#(\d+)',
                                                   url: 'https://developerbugs.linuxfoundation.org',
                                                   label: 'lf#@@@', show_url: 'https://developerbugs.linuxfoundation.org/show_bug.cgi?id=@@@')
  end

  def down
    IssueTracker.find_by(name: 'lf').destroy
  end
end
