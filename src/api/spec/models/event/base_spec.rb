require 'rails_helper'

RSpec.describe Event::Base do
  describe '#package_watchers' do
    context 'when the package and project exists' do
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

      subject { event.package_watchers }

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
      let(:package) { create(:package, name: 'ruby') }
      let(:event) do
        Event::BuildFail.create(package: package.name,
                                project: 'nonexistent',
                                repository: 'openSUSE_Tumbleweed',
                                arch: 'x86_64',
                                reason: '')
      end
      let(:user) { create(:confirmed_user) }

      subject { event.package_watchers }

      it { expect(subject).to be_empty }
    end

    context 'when the package is missing' do
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

      subject { event.package_watchers }

      it { expect(subject).to be_empty }
    end
  end

  describe '#request_watchers' do
    let(:bs_request) { create(:bs_request_with_submit_action) }
    let(:event) { Event::RequestStatechange.create(number: bs_request.number) }
    let(:user) { create(:confirmed_user) }

    subject { event.request_watchers }

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

  describe '#watchers' do
    let(:project) { create(:project, name: 'openSUSE') }
    let(:event) { Event::CommentForProject.create(project: project.name) }
    let(:user) { create(:confirmed_user) }

    subject { event.watchers }

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
end
