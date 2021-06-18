require 'rails_helper'

RSpec.describe IssueTrackersController do
  render_views
  let(:invalid_xml) { '<issue-tracker></issue>' }
  let(:admin_user) { create(:admin_user) }
  let(:confirmed_user) { create(:confirmed_user) }
  let!(:issue_tracker) { create(:issue_tracker) }

  describe 'GET /issue_trackers' do
    before do
      get :index, format: :xml
    end

    it { expect(response).to have_http_status(:success) }

    it { expect(response.body).not_to be_empty }

    it { expect(response.body).to have_xpath('//issue-trackers') }
  end

  describe 'GET /show' do
    before do
      get :index, format: :xml, params: { name: issue_tracker.name }
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(response.body).to have_xpath('//issue-tracker') }
  end

  describe 'POST /create' do
    let(:issue_tracker_xml) do
      <<~XML
        <issue-tracker>
            <name>FOO</name>
            <label>BAR</label>
            <kind>WOW</kind>
            <description/>
            <url>http://example.org</url>
            <show-url>true</show-url>
            <regex>.</regex>
        </issue-tracker>
      XML
    end

    context 'as nobody' do
      context 'invalid XML' do
        before do
          post :create, format: :xml, body: invalid_xml
        end

        it { expect(response).to have_http_status(:forbidden) }
      end

      context 'valid XML' do
        before do
          post :create, format: :xml, body: issue_tracker_xml
        end

        it { expect(response).to have_http_status(:forbidden) }
      end
    end

    context 'as user' do
      context 'invalid XML' do
        before do
          login confirmed_user
          post :create, format: :xml, body: invalid_xml
        end

        it { expect(response).to have_http_status(:forbidden) }
      end

      context 'valid XML' do
        before do
          login confirmed_user
          post :create, format: :xml, body: issue_tracker_xml
        end

        it { expect(response).to have_http_status(:forbidden) }
      end
    end

    context 'as admin' do
      context 'invalid XML' do
        before do
          login admin_user
          post :create, format: :xml, body: invalid_xml
        end

        it { expect(response).to have_http_status(:bad_request) }
      end

      context 'valid XML' do
        before do
          login admin_user
          post :create, format: :xml, body: issue_tracker_xml
        end

        it { expect(response).to have_http_status(:success) }
      end
    end
  end

  describe 'PUT /update' do
    let(:issue_tracker_xml) do
      <<~XML
        <issue-tracker>
            <name>#{issue_tracker.name}</name>
            <label>BAR</label>
            <kind>WOW</kind>
            <description/>
            <url>http://example.org</url>
            <show-url>true</show-url>
            <regex>.</regex>
        </issue-tracker>
      XML
    end

    context 'as nobody' do
      context 'invalid XML' do
        before do
          put :update, format: :xml, body: invalid_xml, params: { name: issue_tracker.name }
        end

        it { expect(response).to have_http_status(:forbidden) }
      end

      context 'valid XML' do
        before do
          put :update, format: :xml, body: issue_tracker_xml, params: { name: issue_tracker.name }
        end

        it { expect(response).to have_http_status(:forbidden) }
      end
    end

    context 'as user' do
      context 'invalid XML' do
        before do
          login confirmed_user
          put :update, format: :xml, body: invalid_xml, params: { name: issue_tracker.name }
        end

        it { expect(response).to have_http_status(:forbidden) }
      end

      context 'valid XML' do
        before do
          login confirmed_user
          put :update, format: :xml, body: issue_tracker_xml, params: { name: issue_tracker.name }
        end

        it { expect(response).to have_http_status(:forbidden) }
      end
    end

    context 'as admin' do
      context 'invalid XML' do
        before do
          login admin_user
          put :update, format: :xml, body: invalid_xml, params: { name: issue_tracker.name }
        end

        it { expect(response).to have_http_status(:bad_request) }
      end

      context 'valid XML' do
        before do
          login admin_user
          put :update, format: :xml, body: issue_tracker_xml, params: { name: issue_tracker.name }
        end

        it { expect(response).to have_http_status(:success) }
      end
    end
  end

  describe 'DELETE /issue_trackers' do
    context 'as nobody' do
      before do
        delete :destroy, format: :xml, params: { name: issue_tracker.name }
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'as user' do
      before do
        login confirmed_user
        delete :destroy, format: :xml, params: { name: issue_tracker.name }
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'as admin' do
      before do
        login admin_user
        delete :destroy, format: :xml, params: { name: issue_tracker.name }
      end

      it { expect(response).to have_http_status(:success) }
    end
  end
end
