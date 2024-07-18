RSpec.describe BsRequest::FindFor::User do
  describe '#all' do
    let(:klass) { BsRequest::FindFor::User }
    let(:user) { create(:confirmed_user) }
    let(:another_user) { create(:confirmed_user) }
    let(:target_package) { create(:package) }
    let(:target_project) { target_package.project }
    let(:source_package) { create(:package) }
    let(:source_project) { source_package.project }

    shared_examples 'has a request' do
      let(:another_target_package) { create(:package) }
      let(:another_target_project) { another_target_package.project }

      it { expect(klass.new(user: user.login).all).to include(request) }
      it { expect(klass.new(user: user.login, roles: role).all).to include(request) }
      it { expect(klass.new(user: user.login, roles: :not_existent).all).not_to include(request) }
      it { expect(klass.new(user: user.login).all).not_to include(another_request) }
    end

    context 'with a not existing user' do
      subject { klass.new(user: 'not-existent') }

      it { expect { subject.all }.to raise_error(NotFoundError) }
    end

    context 'with a created request' do
      it_behaves_like 'has a request' do
        let(:role) { :creator }
        let!(:request) do
          create(:bs_request_with_submit_action,
                 creator: user,
                 target_project: target_project,
                 source_package: source_package)
        end
        let!(:another_request) do
          create(:bs_request_with_submit_action,
                 creator: another_user,
                 target_project: another_target_project,
                 source_package: source_package)
        end
      end
    end

    context 'with a group maintainer relationship' do
      let(:role) { :maintainer }
      let(:group) { create(:group) }
      let!(:groups_user) { create(:groups_user, user: user, group: group) }
      let!(:request) do
        create(:bs_request_with_submit_action,
               creator: another_user,
               target_package: target_package,
               source_package: source_package)
      end
      let!(:another_request) do
        create(:bs_request_with_submit_action,
               creator: another_user,
               target_package: another_target_package,
               source_package: source_package)
      end

      context 'to a project with a request' do
        it_behaves_like 'has a request' do
          let!(:relationship_project_group) { create(:relationship_project_group, project: target_project, group: group) }
        end
      end

      context 'to a package with a request' do
        it_behaves_like 'has a request' do
          let!(:relationship_package_group) { create(:relationship_package_group, package: target_package, group: group) }
        end
      end
    end

    context 'with a direct maintainer relationship' do
      let(:role) { :maintainer }
      let!(:request) do
        create(:bs_request_with_submit_action,
               creator: another_user,
               target_package: target_package,
               source_package: source_package)
      end
      let!(:another_request) do
        create(:bs_request_with_submit_action,
               creator: another_user,

               target_package: another_target_package,
               source_package: source_package)
      end

      context 'to a project with a request' do
        it_behaves_like 'has a request' do
          let!(:relationship_project_user) { create(:relationship_project_user, project: target_project, user: user) }
        end
      end

      context 'to a package with a request' do
        it_behaves_like 'has a request' do
          let!(:relationship_project_user) { create(:relationship_package_user, package: target_package, user: user) }
        end
      end
    end

    context 'with a review' do
      let(:role) { :reviewer }

      context 'and a state' do
        let(:request) { create(:set_bugowner_request, creator: another_user) }
        let!(:review) { create(:review, by_user: user, bs_request: request, state: :accepted) }

        let!(:another_request) { create(:set_bugowner_request, creator: another_user, review_by_user: user) }

        context 'submitted as array' do
          subject { klass.new(user: user.login, review_states: %i[accepted new]).all }

          it { expect(subject).to include(request) }
          it { expect(subject).to include(another_request) }
        end

        context 'submitted as symbol' do
          subject { klass.new(user: user.login, review_states: :accepted).all }

          it { expect(subject).to include(request) }
          it { expect(subject).not_to include(another_request) }
        end
      end

      context 'by user' do
        it_behaves_like 'has a request' do
          let(:request) { create(:set_bugowner_request, creator: another_user) }
          let!(:review) { create(:review, by_user: user, bs_request: request) }

          let(:another_request) { create(:set_bugowner_request, creator: another_user) }
          let!(:another_review) { create(:review, by_user: another_user, bs_request: another_request) }
        end
      end

      context 'by group' do
        it_behaves_like 'has a request' do
          let(:group) { create(:group) }
          let!(:groups_user) { create(:groups_user, user: user, group: group) }
          let(:request) { create(:set_bugowner_request, creator: another_user) }
          let!(:review) { create(:review, by_group: group.title, bs_request: request) }

          let(:another_group) { create(:group) }
          let(:another_request) { create(:set_bugowner_request, creator: another_user) }
          let!(:another_review) { create(:review, by_group: another_group.title, bs_request: another_request) }
        end
      end

      context 'by project' do
        it_behaves_like 'has a request' do
          let(:request) { create(:set_bugowner_request, creator: another_user) }
          let!(:review) { create(:review, by_project: target_project, bs_request: request) }
          let!(:relationship_project_user) { create(:relationship_project_user, project: target_project, user: user) }

          let(:another_request) { create(:set_bugowner_request, creator: another_user, review_by_project: another_target_project) }
        end
      end

      context 'by package' do
        it_behaves_like 'has a request' do
          let!(:request) { create(:set_bugowner_request, creator: another_user, review_by_package: target_package) }
          let!(:relationship_package_group) { create(:relationship_package_user, package: target_package, user: user) }

          let!(:another_request) { create(:set_bugowner_request, creator: another_user, review_by_package: another_target_package) }
        end
      end
    end

    context 'as maintainer or reviewer or creator' do
      subject { klass.new(user: user.login).all }

      let(:review_request) { create(:set_bugowner_request, creator: another_user) }
      let!(:review) { create(:review, by_user: user, bs_request: review_request) }

      let!(:relationship_project_user) { create(:relationship_project_user, project: target_project, user: user) }
      let!(:maintainer_request) do
        create(:bs_request_with_submit_action,
               creator: another_user,
               target_package: target_package,
               source_package: source_package)
      end

      let(:creator_request) { create(:set_bugowner_request, creator: user) }

      it { expect(subject).to include(review_request) }
      it { expect(subject).to include(maintainer_request) }
    end
  end
end
