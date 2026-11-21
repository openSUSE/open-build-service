RSpec.describe Webui::GroupHelper do
  describe '#group_with_icon' do
    let(:group) { create(:group, title: 'test_group') }

    it 'returns group link and image for a Group object' do
      expect(helper.group_with_icon(group)).to include('test_group', '/groups/test_group')
    end

    it 'returns group link and image for a group title string' do
      group
      expect(helper.group_with_icon('test_group')).to include('test_group', '/groups/test_group')
    end

    it 'returns fallback string when group does not exist' do
      expect(helper.group_with_icon('nonexistent_group')).to eq('nonexistent_group')
    end
  end
end
