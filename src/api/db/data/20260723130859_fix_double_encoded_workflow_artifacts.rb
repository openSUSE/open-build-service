# frozen_string_literal: true

class FixDoubleEncodedWorkflowArtifacts < ActiveRecord::Migration[7.2]
  def up
    WorkflowArtifactsPerStep.find_each do |record|
      # AR's serialize :artifacts, coder: JSON decodes one level on read.
      # A double-encoded record yields a String instead of a Hash after that decode.
      next unless record.artifacts.is_a?(String)

      # record.artifacts is the inner JSON string (one level already decoded by AR).
      # Parse it into a Hash, re-encode as JSON, and write directly via raw SQL.
      # update_columns still goes through the AR type layer for text columns, which
      # would double-encode again, so we use raw SQL to write the value verbatim.
      conn = WorkflowArtifactsPerStep.connection
      single_encoded = JSON.parse(record.artifacts).to_json
      conn.execute("UPDATE workflow_artifacts_per_steps SET artifacts = #{conn.quote(single_encoded)} WHERE id = #{record.id}")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
