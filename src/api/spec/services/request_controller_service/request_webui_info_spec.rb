require 'rails_helper'

RSpec.describe ::RequestControllerService::RequestWebuiInfo do
  let(:bs_request) { create(:bs_request_with_submit_action) }
  let(:author_user) { User.find_by(login: bs_request.creator) }
  let(:other_user) { create(:confirmed_user, login: 'foobar') }
  let(:target_project) { other_user.home_project }
  let(:target_package) { create(:package_with_file, name: 'goal', project_id: target_project.id) }
  let(:source_project) { author_user.home_project }
  let(:source_package) { create(:package, :as_submission_source, name: 'ball', project: source_project) }
  let(:bs_request_with_package) do
    create(:bs_request_with_submit_action,
           description: 'Please take this',
           creator: other_user,
           target_package: target_package,
           source_package: source_package)
  end

  describe '#new' do
    it { expect { ::RequestControllerService::RequestWebuiInfo.new(bs_request, diff_limit: 0, current_user: author_user, diff_to_superseded: nil) }.not_to raise_error }
  end

  describe '#author?' do
    context 'when its true' do
      let(:request_webui_info) do
        ::RequestControllerService::RequestWebuiInfo.new(bs_request, diff_limit: 0, current_user: author_user, diff_to_superseded: nil)
      end
      it { expect(request_webui_info).to be_author }
    end

    context 'when it is false' do
      let(:other_user) { create(:confirmed_user, login: 'foobar') }
      let(:request_webui_info) do
        ::RequestControllerService::RequestWebuiInfo.new(bs_request, diff_limit: 0, current_user: other_user, diff_to_superseded: nil)
      end

      it { expect(request_webui_info).not_to be_author }
    end
  end

  describe '#can_add_reviews?' do
    context 'when its true' do
      let(:request_webui_info) do
        ::RequestControllerService::RequestWebuiInfo.new(bs_request, diff_limit: 0, current_user: author_user, diff_to_superseded: nil)
      end
      it { expect(request_webui_info).to be_can_add_review }
    end

    context 'when its true' do
      let(:request_webui_info) do
        ::RequestControllerService::RequestWebuiInfo.new(bs_request, diff_limit: 0, current_user: other_user, diff_to_superseded: nil)
      end
      it { expect(request_webui_info).not_to be_can_add_review }
    end
  end

  describe '#can_handle_request?' do
    context 'when its true' do
      let(:request_webui_info) do
        ::RequestControllerService::RequestWebuiInfo.new(bs_request, diff_limit: 0, current_user: author_user, diff_to_superseded: nil)
      end
      it { expect(request_webui_info).to be_can_handle_request }
    end

    context 'when its true' do
      let(:request_webui_info) do
        ::RequestControllerService::RequestWebuiInfo.new(bs_request, diff_limit: 0, current_user: other_user, diff_to_superseded: nil)
      end
      it { expect(request_webui_info).not_to be_can_handle_request }
    end
  end

  describe '#package_maintainers' do
    let(:request_webui_info) do
      ::RequestControllerService::RequestWebuiInfo.new(bs_request_with_package, diff_limit: 0,
                                                                                current_user: other_user, diff_to_superseded: nil)
    end

    context 'no maintainer assigned' do
      it { expect(request_webui_info.package_maintainers).to eq([]) }
    end

    context 'package maintainer assigned' do
      let!(:relationship_package_user) { create(:relationship_package_user, user: other_user, package: target_package) }
      it { expect(request_webui_info.package_maintainers).to include(other_user) }
    end
  end

  describe '#show_project_maintainer_hint?' do
    let(:request_webui_info) do
      ::RequestControllerService::RequestWebuiInfo.new(bs_request, diff_limit: 0,
                                                                   current_user: other_user, diff_to_superseded: nil)
    end
    it { expect(request_webui_info).not_to be_show_project_maintainer_hint }
  end

  describe 'not_full_diff?' do
    context 'when its false' do
      let(:request_webui_info) do
        ::RequestControllerService::RequestWebuiInfo.new(bs_request, diff_limit: 0,
                                                                     current_user: other_user, diff_to_superseded: nil)
      end
      it { expect(request_webui_info).not_to be_not_full_diff }
    end

    context 'when its true' do
      skip 'not working'
      let(:request_webui_info) do
        ::RequestControllerService::RequestWebuiInfo.new(bs_request_with_package, diff_limit: 10,
                                                                                  current_user: other_user, diff_to_superseded: nil)
      end
      before do
        stub_const('BsRequestAction::Differ::ForSource::DEFAULT_FILE_LIMIT', 5)
      end

      it { expect(request_webui_info).to be_not_full_diff }
    end
  end
end
