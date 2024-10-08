RSpec.describe BsRequest::FindFor::Group do
  describe '#all' do
    let(:klass) { BsRequest::FindFor::Group }
    let(:user) { create(:confirmed_user) }
    let(:group) { create(:group) }
    let(:target_package) { create(:package) }
    let(:target_project) { target_package.project }
    let(:source_package) { create(:package) }
    let(:source_project) { source_package.project }

    shared_examples 'has a request' do
      let(:another_target_package) { create(:package) }
      let(:another_target_project) { another_target_package.project }

      it { expect(klass.new(group: group.title).all).to include(request) }
      it { expect(klass.new(group: group.title, roles: role).all).to include(request) }
      it { expect(klass.new(group: group.title, roles: :not_existent).all).not_to include(request) }
      it { expect(klass.new(group: group.title).all).not_to include(another_request) }
    end

    context 'with a not existing group' do
      subject { klass.new(group: 'not-existent') }

      it { expect { subject.all }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'with a group maintainer relationship' do
      let(:role) { :maintainer }

      context 'to a project with a request' do
        it_behaves_like 'has a request' do
          let!(:relationship_project_group) { create(:relationship_project_group, project: target_project, group: group) }
          let!(:request) do
            create(:bs_request_with_submit_action,
                   creator: user,
                   target_project: target_project,
                   source_package: source_package)
          end
          let!(:another_request) do
            create(:bs_request_with_submit_action,
                   creator: user,
                   target_project: another_target_project,
                   source_package: source_package)
          end
        end
      end

      context 'to a package with a request' do
        it_behaves_like 'has a request' do
          let!(:relationship_package_group) { create(:relationship_package_group, package: target_package, group: group) }
          let!(:request) do
            create(:bs_request_with_submit_action,
                   creator: user,
                   target_package: target_package,
                   source_package: source_package)
          end
          let!(:another_request) do
            create(:bs_request_with_submit_action,
                   creator: user,
                   target_package: another_target_package,
                   source_package: source_package)
          end
        end
      end
    end

    context 'with a review' do
      let(:role) { :reviewer }

      context 'by group' do
        it_behaves_like 'has a request' do
          let(:request) { create(:set_bugowner_request, creator: user) }
          let!(:review) { create(:review, by_group: group, bs_request: request) }

          let(:another_group) { create(:group) }
          let(:another_request) { create(:set_bugowner_request, creator: user) }
          let!(:another_review) { create(:review, by_group: another_group, bs_request: another_request) }
        end
      end

      context 'by project' do
        it_behaves_like 'has a request' do
          let(:request) { create(:set_bugowner_request, creator: user) }
          let!(:review) { create(:review, by_project: target_project, bs_request: request) }
          let!(:relationship_project_group) { create(:relationship_project_group, project: target_project, group: group) }

          let(:another_request) { create(:set_bugowner_request, creator: user) }
          let!(:another_review) { create(:review, by_project: another_target_project.name, bs_request: another_request) }
        end
      end

      context 'by package' do
        it_behaves_like 'has a request' do
          let(:request) { create(:set_bugowner_request, creator: user) }
          let!(:review) { create(:review, by_project: target_project, by_package: target_package, bs_request: request) }
          let!(:relationship_package_group) { create(:relationship_package_group, package: target_package, group: group) }

          let(:another_request) { create(:set_bugowner_request, creator: user) }
          let!(:another_review) do
            create(:review,
                   by_project: another_target_project,
                   by_package: another_target_package,
                   bs_request: another_request)
          end
        end
      end
    end

    context 'as maintainer or reviewer' do
      subject { klass.new(group: group.title).all }

      let(:review_request) { create(:set_bugowner_request, creator: user) }
      let!(:review) { create(:review, by_group: group.title, bs_request: review_request) }

      let!(:relationship_project_group) { create(:relationship_project_group, project: target_project, group: group) }
      let!(:maintainer_request) do
        create(:bs_request_with_submit_action,
               creator: user,
               target_package: target_package,
               source_package: source_package)
      end

      it { expect(subject).to include(review_request) }
      it { expect(subject).to include(maintainer_request) }
    end
  end
end
