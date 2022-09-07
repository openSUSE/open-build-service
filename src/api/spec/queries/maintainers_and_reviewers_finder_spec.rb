require 'rails_helper'

RSpec.describe MaintainersAndReviewersFinder do
  let(:user) { create(:user) }
  let(:review) { create(:review, by_user: user) }
  let(:project) { create(:project_with_package, name: 'Apache', package_name: 'apache2') }
  let(:package) { project.packages.first }
  let(:other_user) { create(:user, login: 'bob') }

  describe '.for_package' do
    subject { described_class.new(review).for_package }

    context 'when we have users as maintainers in that package' do
      let(:maintainer) { Role.hashed['maintainer'] }

      before do
        package.relationships.create(user: other_user, role: maintainer)
        review.package = package
      end

      it 'returns those users as reviewers' do
        expect(subject).to contain_exactly(other_user)
      end
    end

    context 'when we have groups with users as maintainers in that package' do
      let(:other_group) { create(:group, title: 'my_group', users: [other_user]) }
      let(:maintainer) { Role.hashed['maintainer'] }

      before do
        package.relationships.create(group: other_group, role: maintainer)
        review.package = package
      end

      it 'returns those users as reviewers' do
        expect(subject).to contain_exactly(other_user)
      end
    end

    context 'when we have no maintainers of any form in the package' do
      let(:bugowner) { Role.hashed['bugowner'] }

      before do
        package.relationships.create(user: other_user, role: bugowner)
        review.package = package
      end

      it { expect(subject).to be_empty }
    end
  end

  describe '.for_project' do
    subject { described_class.new(review).for_project }

    context 'when we have users as maintainers in that project' do
      let(:maintainer) { Role.hashed['maintainer'] }

      before do
        project.relationships.create(user: other_user, role: maintainer)
        review.package = package
      end

      it 'returns those users as reviewers' do
        expect(subject).to contain_exactly(other_user)
      end
    end

    context 'when we have groups with users as maintainers in that project' do
      let(:other_group) { create(:group, title: 'my_group', users: [other_user]) }
      let(:maintainer) { Role.hashed['maintainer'] }

      before do
        project.relationships.create(group: other_group, role: maintainer)
        review.package = package
      end

      it 'returns those users as reviewers' do
        expect(subject).to contain_exactly(other_user)
      end
    end

    context 'when we have no maintainers of any form in the project' do
      let(:bugowner) { Role.hashed['bugowner'] }

      before do
        project.relationships.create(user: other_user, role: bugowner)
        review.package = package
      end

      it { expect(subject).to be_empty }
    end
  end
end
