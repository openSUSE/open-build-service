# frozen_string_literal: true

class BackfillReporterOnReports < ActiveRecord::Migration[7.1]
  # rubocop:disable Rails/SkipsModelValidations
  def up
    Report.unscoped.where(reporter_id: nil).in_batches do |batch|
      batch.find_each do |report|
        report.update_columns(reporter_id: report.user_id)
      end
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
