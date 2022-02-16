require 'rails_helper'

RSpec.describe WatchedItem do
  let(:user) { create(:confirmed_user) }

  context 'when watching a project' do
    let(:project) { create(:project) }
    let(:watched_item) { create(:watched_item, :for_projects) }

    it 'is valid with valid attributes' do
      expect(watched_item).to be_valid
    end

    it 'is not valid when missing a project' do
      watched_item = build(:watched_item, :for_projects, watchable: nil)
      expect(watched_item).not_to be_valid
      expect(watched_item.errors.full_messages).to include('Watchable must exist')
    end

    context 'when missing the user' do
      let(:watched_item) { build(:watched_item, :for_projects, user: nil) }

      it 'is not valid' do
        expect(watched_item).not_to be_valid
        expect(watched_item.errors.full_messages).to eql(['User must exist'])
      end
    end

    context 'when the user tries to add the same project twice to the watchlist' do
      let(:watched_item) { build(:watched_item, :for_projects, watchable: project, user: user) }

      before { create(:watched_item, :for_projects, watchable: project, user: user) }

      it 'is not valid' do
        expect(watched_item).not_to be_valid
        expect(watched_item.errors.full_messages).to eql(['Watchable has already been taken'])
      end
    end

    context 'when the user tries to add different projects to the watchlist' do
      let(:user) { create(:confirmed_user) }
      let(:watched_item) { build(:watched_item, :for_projects, user: user) }

      before { create(:watched_item, :for_projects, user: user) }

      it 'is valid' do
        expect(watched_item).to be_valid
      end
    end

    context 'when two different users try to watch the same project' do
      let(:project) { create(:project) }
      let(:watched_item) { create(:watched_item, :for_projects, watchable: project) }

      before { create(:watched_item, :for_projects, watchable: project) }

      it 'is valid' do
        expect(watched_item).to be_valid
      end
    end
  end

  context 'when watching a package' do
    let(:package) { create(:package) }
    let(:watched_item) { build(:watched_item, :for_packages) }

    it 'is valid with valid attributes' do
      expect(watched_item).to be_valid
    end

    context 'when missing a package' do
      it 'is not valid' do
        watched_item = build(:watched_item, :for_packages, watchable: nil)
        expect(watched_item).not_to be_valid
        expect(watched_item.errors.full_messages).to include('Watchable must exist')
      end
    end

    context 'when missing a user' do
      let(:watched_item) { build(:watched_item, :for_packages, user: nil) }

      it 'is not valid' do
        expect(watched_item).not_to be_valid
        expect(watched_item.errors.full_messages).to eql(['User must exist'])
      end
    end

    context 'when the user tries to add the same package twice to the watchlist' do
      let(:watched_item) { build(:watched_item, :for_packages, watchable: package, user: user) }

      before { create(:watched_item, :for_packages, watchable: package, user: user) }

      it 'is not valid' do
        expect(watched_item).not_to be_valid
        expect(watched_item.errors.full_messages).to eql(['Watchable has already been taken'])
      end
    end

    context 'when the user tries to add different packages to the watchlist' do
      let(:watched_item) { build(:watched_item, :for_packages, user: user) }

      before { create(:watched_item, :for_packages, user: user) }

      it 'is valid' do
        expect(watched_item).to be_valid
      end
    end

    context 'when two different users try to watch the same package' do
      let(:watched_item) { create(:watched_item, :for_packages, watchable: package) }

      before { create(:watched_item, :for_packages, watchable: package) }

      it 'is valid' do
        expect(watched_item).to be_valid
      end
    end
  end

  context 'when watching a request' do
    let(:bs_request) { create(:bs_request_with_submit_action) }

    it 'is valid with valid attributes' do
      expect(create(:watched_item, :for_bs_requests)).to be_valid
    end

    context 'when missing a request' do
      it 'is not valid' do
        watched_item = build(:watched_item, :for_bs_requests, watchable: nil)
        expect(watched_item).not_to be_valid
        expect(watched_item.errors.full_messages).to include('Watchable must exist')
      end
    end

    context 'when missing a user' do
      let(:watched_item) { build(:watched_item, :for_bs_requests, user: nil) }

      it 'is not valid' do
        expect(watched_item).not_to be_valid
        expect(watched_item.errors.full_messages).to eql(['User must exist'])
      end
    end

    context 'when the user tries to add the same request twice to the watchlist' do
      let(:watched_item) { build(:watched_item, :for_bs_requests, watchable: bs_request, user: user) }

      before { create(:watched_item, :for_bs_requests, watchable: bs_request, user: user) }

      it 'is not valid' do
        expect(watched_item).not_to be_valid
        expect(watched_item.errors.full_messages).to eql(['Watchable has already been taken'])
      end
    end

    context 'when the user tries to add different requests to the watchlist' do
      let(:watched_item) { build(:watched_item, :for_bs_requests, user: user) }

      before { create(:watched_item, :for_bs_requests, user: user) }

      it 'is valid' do
        expect(watched_item).to be_valid
      end
    end

    context 'when two different users try to watch the same package' do
      let(:request) { create(:bs_request) }
      let(:watched_item) { create(:watched_item, :for_bs_requests, watchable: bs_request) }

      before { create(:watched_item, :for_bs_requests, watchable: bs_request) }

      it 'is valid' do
        expect(watched_item).to be_valid
      end
    end
  end
end
