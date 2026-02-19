RSpec.describe Event::Base do
  describe '#package_watchers' do
    context 'when the package and project exists' do
      subject { event.package_watchers }

      let(:project) { create(:project_with_repository) }
      let(:package) { create(:package, name: 'ruby', project: project) }
      let(:repository) { project.repositories.first }
      let(:arch) { repository.architectures.first }
      let(:event) do
        Event::BuildFail.create(package: package.name,
                                project: project.name,
                                repository: repository,
                                arch: arch,
                                reason: '')
      end
      let(:user) { create(:confirmed_user) }

      context 'when the package is being watched' do
        before do
          WatchedItem.create(watchable: package, user: user)
        end

        it 'includes the watcher of the package' do
          expect(subject).to include(user)
        end
      end

      context 'when the package is not being watched' do
        it { expect(subject).to be_empty }
      end
    end

    context 'when the project is missing' do
      subject { event.package_watchers }

      let(:package) { create(:package, name: 'ruby') }
      let(:event) do
        Event::BuildFail.create(package: package.name,
                                project: 'nonexistent',
                                repository: 'openSUSE_Tumbleweed',
                                arch: 'x86_64',
                                reason: '')
      end
      let(:user) { create(:confirmed_user) }

      it { expect(subject).to be_empty }
    end

    context 'when the package is missing' do
      subject { event.package_watchers }

      let(:project) { create(:project_with_repository) }
      let(:package) { create(:package, name: 'ruby', project: project) }
      let(:repository) { project.repositories.first }
      let(:arch) { repository.architectures.first }
      let(:event) do
        Event::BuildFail.create(package: 'nonexistent',
                                project: project.name,
                                repository: repository.name,
                                arch: arch.name,
                                reason: '')
      end
      let(:user) { create(:confirmed_user) }

      it { expect(subject).to be_empty }
    end
  end

  describe '#request_watchers' do
    subject { event.request_watchers }

    let(:bs_request) { create(:bs_request_with_submit_action) }
    let(:event) { Event::RequestStatechange.create(number: bs_request.number) }
    let(:user) { create(:confirmed_user) }

    context 'when the request is being watched' do
      before do
        WatchedItem.create(watchable: bs_request, user: user)
      end

      it 'includes the watcher of the request' do
        expect(subject).to include(user)
      end
    end

    context 'when the request is not watched' do
      it { expect(subject).to be_empty }
    end
  end

  describe '#project_watchers' do
    subject { event.project_watchers }

    let(:project) { create(:project, name: 'openSUSE') }
    let(:event) { Event::CommentForProject.create(project: project.name) }
    let(:user) { create(:confirmed_user) }

    context 'when the project is being watched' do
      before do
        WatchedItem.create(watchable: project, user: user)
      end

      it 'includes the watcher of the project' do
        expect(subject).to include(user)
      end
    end

    context 'when the project is not watched' do
      it { expect(subject).to be_empty }
    end
  end

  describe '#subscriptions' do
    subject { event.subscriptions(:instant_email) }

    context 'for events that do not send notifications' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let(:source_package) { create(:package, name: 'ruby') }
      let(:target_package) { create(:package) }
      let(:event) do
        Event::RequestReviewsDone.create(number: bs_request.number,
                                         actions: [{ action_id: 1,
                                                     type: 'submit',
                                                     sourceproject: source_package.project.name,
                                                     sourcepackage: source_package.name,
                                                     targetproject: target_package.project.name,
                                                     targetpackage: target_package.name }])
      end

      it 'returns no subscriptions' do
        expect(subject).to be_empty
      end
    end

    context 'for events that do send notifications' do
      let(:maintainer) { create(:confirmed_user) }
      let!(:project) { create(:project, maintainer: [maintainer]) }
      let!(:comment) { create(:comment_project, commentable: project) }
      let!(:subscription) { create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'maintainer', subscriber: maintainer) }
      let(:event) { Event::CommentForProject.first }

      it 'returns the subscription for that user/group' do
        expect(subject).not_to(be_empty)
      end
    end
  end

  describe '#develpackage_or_package_maintainers' do
    subject { event.develpackage_or_package_maintainers }

    let(:package_maintainer) { create(:confirmed_user) }
    let(:project) do
      project = create(:project)
      project.update_column(:anitya_distribution_name, 'Anitdist') # rubocop:disable Rails/SkipsModelValidations
      project.store
      project
    end
    let(:package) { create(:package, project: project, develpackage: develpackage) }
    let!(:package_maintainer_role) { create(:relationship, package: package, user: package_maintainer) }
    let!(:package_maintainer_subscription) { create(:event_subscription_upstream_version, subscriber: package_maintainer) }
    # This creation on a PackageVersionUpstream object ends up creating the related event
    let!(:package_version_upstream) { create(:package_version_upstream, package: package) }
    let(:event) { Event::UpstreamPackageVersionChanged.last }

    context "when the package don't have a devel package" do
      let(:develpackage) { nil }

      it 'only the maintainer receive the notification' do
        expect(subject).to contain_exactly(package_maintainer)
      end
    end

    context 'when the package has a devel package' do
      let(:develpackage_maintainer) { create(:confirmed_user) }
      let(:develpackage) { create(:package, project: project) }
      let!(:develpackage_maintainer_role) { create(:relationship, package: develpackage, user: develpackage_maintainer) }
      let!(:develpackage_maintainer_subscription) { create(:event_subscription_upstream_version, subscriber: develpackage_maintainer) }

      it 'only the develpackage maintainer receiver of the notification' do
        expect(subject).to contain_exactly(develpackage_maintainer)
      end
    end
  end
end
