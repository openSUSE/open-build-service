RSpec.describe DistroRelease do
  describe 'name validation' do
    it { is_expected.to allow_value('openSUSE Leap 16').for(:name) }
    it { is_expected.not_to allow_value('Debian GNU/Linux').for(:name) }
    it { is_expected.to allow_value('Ubuntu 24.04').for(:name) }
    it { is_expected.to allow_value('foo_bar').for(:name) }
    it { is_expected.to allow_value('foo-bar').for(:name) }
  end
end
