# frozen_string_literal: true

class AddSavannahBugTracker < ActiveRecord::Migration[7.0]
  def up
    IssueTracker.where(name: 'svg').first_or_create(description: 'GNU Savannah bug tracker',
                                                    kind: 'other',
                                                    regex: 'svg#(\d+)',
                                                    url: 'https://savannah.gnu.org/bugs',
                                                    label: 'svg#@@@', show_url: 'https://savannah.gnu.org/bugs/?@@@')
  end

  def down
    IssueTracker.find_by(name: 'svg').destroy
  end
end
