RSpec.describe WorkflowVersionMatcher do
  let(:dummy_instance) do
    dummy_obj = Object.new
    dummy_obj.extend(WorkflowVersionMatcher)
    dummy_obj
  end

  describe '#feature_available_for_workflow_version?' do
    context 'when no workflow version is provided' do
      it 'uses the fallback version number' do
        expect(dummy_instance.feature_available_for_workflow_version?(workflow_version: nil, feature_name: 'event_aliases')).to be(true)
      end
    end

    context 'when a workflow version is provided which includes the given feature' do
      it { expect(dummy_instance.feature_available_for_workflow_version?(workflow_version: '1.1', feature_name: 'event_aliases')).to be(true) }
    end

    context 'when a workflow version is provided that is higher then the version with the given feature' do
      it { expect(dummy_instance.feature_available_for_workflow_version?(workflow_version: '2.1', feature_name: 'event_aliases')).to be(true) }
    end

    context 'when a feature name is provided that is not part of any workflow version' do
      it { expect(dummy_instance.feature_available_for_workflow_version?(workflow_version: '1.1', feature_name: 'not_available_feature_name')).to be(false) }
    end

    context 'when a workflow version is provided that is lower then the version with the given feature' do
      it { expect(dummy_instance.feature_available_for_workflow_version?(workflow_version: '1.0', feature_name: 'event_aliases')).to be(false) }
    end
  end
end
