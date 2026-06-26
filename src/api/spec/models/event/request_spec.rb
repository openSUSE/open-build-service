RSpec.describe Event::Request do
  describe '#source_package_watcher' do
    subject { event.source_package_watchers }

    let(:bs_request) { create(:bs_request_with_submit_action) }
    let!(:another_source_package) { create(:package, name: 'ruby') }
    let(:source_package) { create(:package, name: 'ruby') }
    let(:target_package) { create(:package) }
    let(:event) do
      Event::CommentForRequest.create(number: bs_request.number,
                                      actions: [{ action_id: 1,
                                                  type: 'submit',
                                                  sourceproject: source_package.project.name,
                                                  sourcepackage: source_package.name,
                                                  targetproject: target_package.project.name,
                                                  targetpackage: target_package.name }])
    end
    let(:user) { create(:confirmed_user) }

    before do
      bs_request.bs_request_actions.first.update(source_project: target_package.project.name,
                                                 source_package: source_package.name,
                                                 target_project: target_package.project.name,
                                                 target_package: target_package.name)
    end

    context 'when the request is being watched' do
      before do
        WatchedItem.create(watchable: source_package, user: user)
      end

      it 'includes the watcher of the request' do
        expect(subject).to include(user)
      end
    end

    context 'when the request is not being watched' do
      it 'does not include any watchers' do
        expect(subject).to be_empty
      end
    end
  end

  describe '#target_package_watcher' do
    subject { event.target_package_watchers }

    let(:bs_request) { create(:bs_request_with_submit_action) }
    let(:source_package) { create(:package) }
    let!(:another_target_package) { create(:package, name: 'ruby') }
    let(:target_package) { create(:package, name: 'ruby') }
    let(:event) do
      Event::CommentForRequest.create(number: bs_request.number,
                                      actions: [{ action_id: 1,
                                                  type: 'submit',
                                                  sourceproject: source_package.project.name,
                                                  sourcepackage: source_package.name,
                                                  targetproject: target_package.project.name,
                                                  targetpackage: target_package.name },
                                                # The following action will trigger a Project::Errors::UnknownObjectError
                                                { action_id: 2,
                                                  type: 'submit',
                                                  sourceproject: 'nonexistent',
                                                  sourcepackage: 'nonexistent',
                                                  targetproject: 'nonexistent',
                                                  targetpackage: 'nonexistent' }])
    end
    let(:user) { create(:confirmed_user) }

    before do
      bs_request.bs_request_actions.first.update(source_project: target_package.project.name,
                                                 source_package: source_package.name,
                                                 target_project: target_package.project.name,
                                                 target_package: target_package.name)
    end

    context 'when the request is being watched' do
      before do
        WatchedItem.create(watchable: target_package, user: user)
      end

      it 'includes the watcher of the request' do
        expect(subject).to include(user)
      end
    end

    context 'when the request is not being watched' do
      it 'does not include any watchers' do
        expect(subject).to be_empty
      end
    end
  end
end
