require 'rails_helper'
require Rails.root.join('db/data/20220126223735_add_word_boundary_to_issue_tracker_regex.rb')

RSpec.describe AddWordBoundaryToIssueTrackerRegex, type: :migration do
  before do
    # Meanwhile there is a validation in place that checks for the word boundary on
    # the issue tracker regex. In order to test if the data migration works, we
    # have to skip the validation here.
    IssueTracker.new(name: 'bar', kind: 'bugzilla', description: 'this is a description',
                     url: 'http://foo.bar', show_url: 'http://foo.bar', regex: 'bar#(\d+)',
                     label: 'bar#\#@@@', issues_updated: Time.zone.now).save(validate: false)
  end

  # DatabaseCleaner does not clean the issue_trackers table, we have to do it manually
  after do
    IssueTracker.last.delete
  end

  describe '.up' do
    before do
      AddWordBoundaryToIssueTrackerRegex.new.up
    end

    it 'concat \b before and after the regex' do
      expect(IssueTracker.last.regex).to match('\bbar#(\\d+)\b')
    end
  end

  describe '.down' do
    before do
      AddWordBoundaryToIssueTrackerRegex.new.down
    end

    it 'remove \b from the beginning and end of the regex' do
      expect(IssueTracker.last.regex).to eq('bar#(\d+)')
    end
  end
end
