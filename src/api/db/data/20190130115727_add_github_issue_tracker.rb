class AddGithubIssueTracker < ActiveRecord::Migration[5.1]
  def up
    IssueTracker.where(name: 'gh').first_or_create(description: 'Generic github tracker',
                                                   kind: 'github',
                                                   regex: '(?:gh|github)#([\w-]+\/[\w-]+#\d+)',
                                                   url: 'https://www.github.com',
                                                   label: 'gh#@@@', show_url: 'https://github.com/@@@')
  end

  def down
    IssueTracker.find_by(name: 'gh').destroy
  end
end
