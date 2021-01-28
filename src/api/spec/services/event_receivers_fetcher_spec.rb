require 'rails_helper'

RSpec.describe EventReceiversFetcher, type: :service do
  describe '#call' do
    # Create package with an inherited maintainer
    let!(:inherited_maintainer) { create(:confirmed_user, :with_home) }
    let!(:project) { inherited_maintainer.home_project }
    let!(:package) { create(:package, project: project) }

    # Create event receivers
    let!(:receiver_role) { :target_maintainer }
    let!(:user) { create(:confirmed_user) }
    let!(:group) { create(:group) }
    let!(:user_in_group) { create(:groups_user, user: create(:confirmed_user), group: group) }

    before do
      create(:groups_user, user: create(:confirmed_user), group: group, email: false)
    end

    subject { described_class.new(Event::RequestCreate.first, receiver_role).call }

    context 'when fetching event receivers for a request created on a package' do
      context 'which has explicit maintainers' do
        # Mark user and group as maintainer of the package
        before do
          create(:relationship_package_user, package: package, user: user, role: Role.find_by_title('maintainer'))
          create(:relationship_package_group, package: package, group: group, role: Role.find_by_title('maintainer'))

          # Add explicit maintainer in the group, making it a duplicate
          create(:groups_user, user: user, group: group)

          # Trigger event by submitting a request to the package maintained by user and group
          create(:bs_request_with_submit_action, state: :new, target_package: package)
        end

        it 'returns all explicit unique maintainers of that package' do
          expect(subject).to match_array([user, user_in_group])
        end
      end

      context 'which has inherited maintainers' do
        before do
          # Trigger event by submitting a request to the package maintained by user and group
          create(:bs_request_with_submit_action, state: :new, target_package: package)
        end

        it 'returns all inherited unique maintainers of the package' do
          expect(subject).to match_array([inherited_maintainer])
        end
      end
    end
  end
end
