require 'rails_helper'

RSpec.describe Webui::RequestController do
  let(:submitter) { create(:confirmed_user, login: 'kugelblitz' ) }
  let(:receiver) { create(:confirmed_user, login: 'titan' ) }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package, name: 'goal', project_id: target_project.id) }
  let(:source_project) { submitter.home_project }
  let(:source_package) { create(:package, name: 'ball', project_id: source_project.id) }
  let(:bs_request) { create(:bs_request, description: "Please take this", creator: submitter.login) }
  let(:create_submit_request) do
    bs_request.bs_request_actions.delete_all
    create(:bs_request_action_submit, target_project: target_project.name,
                                      target_package: source_package.name,
                                      source_project: source_project.name,
                                      source_package: source_package.name,
                                      bs_request_id: bs_request.id)
  end

  it { is_expected.to use_before_action(:require_login) }
  it { is_expected.to use_before_action(:require_request) }

  describe 'GET show' do
    it 'is successful as nobody' do
      get :show, number: bs_request.number
      expect(response).to have_http_status(:success)
    end

    it 'assigns @bsreq' do
      get :show, number: bs_request.number
      expect(assigns(:bsreq)).to eq(bs_request)
    end

    it 'redirects to root_path if request does not exist' do
      login submitter
      get :show, number: '200000'
      expect(flash[:error]).to eq("Can't find request 200000")
      expect(response).to redirect_to(user_show_path(User.current))
    end
  end

  describe "POST #delete_request" do
    before do
      login(submitter)
    end

    context "a valid request" do
      before do
        post :delete_request, project: target_project, package: target_package, description: "delete it!"
        @bs_request = BsRequest.joins(:bs_request_actions).
          where("bs_request_actions.target_project=? AND bs_request_actions.target_package=? AND type=?",
                target_project.to_s, target_package.to_s, "delete"
               ).first
      end

      it { expect(response).to redirect_to(request_show_path(number: @bs_request)) }
      it { expect(flash[:success]).to match("Created .+repository delete request #{@bs_request.number}") }

      it "creates a delete request with the correct description" do
        expect(@bs_request).not_to be nil
        expect(@bs_request.description).to eq("delete it!")
      end
    end

    context "a request causing a APIException" do
      before do
        BsRequest.any_instance.stubs(:save!).raises(APIException, "something happened")
        post :delete_request, project: target_project, package: target_package, description: "delete it!"
      end

      it { expect(flash[:error]).to eq("something happened") }
      it { expect(response).to redirect_to(package_show_path(project: target_project, package: target_package)) }

      it "does not create a delete request" do
        expect(BsRequest.count).to eq(0)
      end
    end
  end
end
