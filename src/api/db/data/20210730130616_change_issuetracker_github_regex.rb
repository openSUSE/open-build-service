# frozen_string_literal: true

# rubocop:disable Rails/SkipsModelValidations
# We don't want the IssueTracker callbacks to run...
class ChangeIssuetrackerGithubRegex < ActiveRecord::Migration[6.1]
  def up
    IssueTracker.where(name: 'gh').update_all(regex: '(?:gh|github)#([\w-]+\/[\w-]+#\d+)')
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
# rubocop:enable Rails/SkipsModelValidations
