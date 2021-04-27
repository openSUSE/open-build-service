require 'rails_helper'

RSpec.describe Token::RebuildPolicy do
  subject { described_class }

  describe '#create' do
    context 'user inactive' do
      let(:user_token) { create(:rebuild_token, :with_package_from_association_or_params, user: user) }

      include_examples 'non-active users cannot use a token'
    end

    context 'user active' do
      let(:user_token) { create(:rebuild_token, :with_package_from_association_or_params, user: user, package: package) }
      let(:other_user_token) { create(:rebuild_token, :with_package_from_association_or_params, user: other_user) }

      include_examples 'active users token basic tests'
    end

    context 'project links' do
      let(:user) { create(:confirmed_user, login: 'foo') }
      let(:user_project) { create(:project, maintainer: user, link_to: other_user_project) }
      let(:other_user_project) { create(:project) }
      let(:other_user_package) { create(:package, project: other_user_project) }
      let(:user_token) do
        create(:rebuild_token, package: nil,
                               package_from_association_or_params: other_user_package,
                               project_from_association_or_params: user_project,
                               user: user)
      end

      before do
        other_user_package
        user_project
      end

      permissions :create? do
        it { expect(subject).to permit(user, user_token) }
      end
    end
  end
end
