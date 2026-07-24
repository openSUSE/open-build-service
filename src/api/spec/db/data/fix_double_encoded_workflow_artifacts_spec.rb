require Rails.root.join('db/data/20260723130859_fix_double_encoded_workflow_artifacts.rb')

RSpec.describe FixDoubleEncodedWorkflowArtifacts, type: :migration do
  describe '#up' do
    let(:workflow_run) { create(:workflow_run) }
    let(:record) { create(:workflow_artifacts_per_step, workflow_run: workflow_run) }

    context 'when artifacts is double-encoded (legacy record)' do
      before do
        # Simulate a legacy double-encoded record by writing the value directly
        # via raw SQL, bypassing ActiveRecord's serialize layer.
        conn = WorkflowArtifactsPerStep.connection
        double_encoded = { source_project: 'home:foo', source_package: 'bar',
                           target_project: 'home:foo:target', target_package: 'bar' }.to_json.to_json
        conn.execute("UPDATE workflow_artifacts_per_steps SET artifacts = #{conn.quote(double_encoded)} WHERE id = #{record.id}")
      end

      it 'fixes the record so artifacts is deserialized as a Hash' do
        described_class.new.up
        expect(record.reload.artifacts).to be_a(Hash)
      end

      it 'preserves the artifacts content' do
        described_class.new.up
        expect(record.reload.artifacts).to include('source_project' => 'home:foo', 'source_package' => 'bar')
      end
    end

    context 'when artifacts is already correctly encoded' do
      it 'leaves the record unchanged' do
        expect { described_class.new.up }.not_to(change { record.reload.artifacts })
      end
    end
  end
end