RSpec.describe User, '.local_permission?' do
  subject { user.local_permission?(perm_string, object) }

  let(:user) { create(:confirmed_user) }

  describe 'package' do
    let(:object) { create(:package) }
    let(:perm_string) { 'change_package' }

    it { expect(subject).to be_falsey }

    context 'has user relationship' do
      let(:object) { create(:package_with_maintainer, maintainer: user) }

      it { expect(subject).to be_truthy }
    end

    context 'has group relationship' do
      let(:group) { create(:group_with_user, user: user) }
      let(:object) { create(:package_with_maintainer, maintainer: group) }

      it { expect(subject).to be_truthy }
    end

    context 'is in user home project' do
      let(:project) { create(:project, name: user.home_project_name) }
      let(:object) { create(:package, project: project) }

      it { expect(subject).to be_truthy }
    end

    context 'is in user home sub-project' do
      let(:project) { create(:project, name: "#{user.home_project_name}:hans") }
      let(:object) { create(:package, project: project) }

      it { expect(subject).to be_truthy }
    end

    context 'parent has user relationship' do
      let(:project) { create(:project, maintainer: user) }
      let(:object) { create(:package, project: project) }

      it { expect(subject).to be_truthy }
    end

    context 'parent has group relationship' do
      let(:group) { create(:group_with_user, user: user) }
      let(:project) { create(:project, maintainer: group) }
      let(:object) { create(:package, project: project) }

      it { expect(subject).to be_truthy }
    end
  end

  describe 'project' do
    let(:object) { create(:project) }
    let(:perm_string) { 'change_project' }

    it { expect(subject).to be_falsey }

    context 'has user relationship' do
      let(:object) { create(:project, maintainer: user) }

      it { expect(subject).to be_truthy }
    end

    context 'has group relationship' do
      let(:group) { create(:group_with_user, user: user) }
      let(:object) { create(:project, maintainer: group) }

      it { expect(subject).to be_truthy }
    end

    context 'is user home project' do
      let(:object) { create(:project, name: user.home_project_name) }

      it { expect(subject).to be_truthy }
    end

    context 'is user home sub-project' do
      let(:object) { create(:project, name: "#{user.home_project_name}:hans") }

      it { expect(subject).to be_truthy }
    end

    context 'parent has user relationship' do
      let!(:project) { create(:project, name: 'ancestor', maintainer: user) }
      let(:object) { create(:project, name: 'ancestor:subproject') }

      it { expect(subject).to be_truthy }
    end

    context 'parent has group relationship' do
      let(:group) { create(:group_with_user, user: user) }
      let!(:project) { create(:project, name: 'ancestor', maintainer: group) }
      let(:object) { create(:project, name: 'ancestor:subproject') }

      it { expect(subject).to be_truthy }
    end
  end
end
