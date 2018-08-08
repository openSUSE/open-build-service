require 'rails_helper'

RSpec.describe AnnouncementsController, type: :controller do
  render_views

  let(:valid_attributes) { attributes_for(:announcement) }
  let(:announcement) { create(:announcement) }
  let(:admin) { create(:admin_user, login: 'admin') }

  before do
    login admin
  end

  describe 'GET #index' do
    context 'when there are announcements' do
      let!(:announcements) { create_list(:announcement, 3) }

      subject! { get :index, format: :xml }

      it 'returns a success response' do
        is_expected.to have_http_status(:success)
      end

      it 'returns all announcements' do
        assert_select 'announcements' do
          announcements.each do |announcement|
            assert_select 'announcement' do
              assert_select 'id',      announcement.id.to_s
              assert_select 'title',   announcement.title
              assert_select 'content', announcement.content
            end
          end
        end
      end
    end

    context 'when there are no announcements' do
      subject! { get :index, format: :xml }

      it 'returns a success response' do
        is_expected.to have_http_status(:success)
      end

      it 'returns an empty announcements xml' do
        assert_select 'announcements' do
          assert_select 'announcement', 0
        end
      end
    end
  end

  describe 'GET #show' do
    subject! { get :show, params: { id: announcement.to_param } }

    it 'returns a success response' do
      is_expected.to have_http_status(:success)
    end

    it 'responds with the announcement' do
      assert_select 'announcement' do
        assert_select 'id',      /\d+/
        assert_select 'title',   announcement.title
        assert_select 'content', announcement.content
      end
    end
  end

  describe 'POST create' do
    context 'with valid params' do
      let(:new_announcement) { build(:announcement) }
      let(:new_announcement_xml) { new_announcement.to_xml(Announcement::DEFAULT_RENDER_PARAMS) }

      subject! { post :create, body: new_announcement_xml, format: :xml }

      it 'creates a new Announcement' do
        expect(Announcement.where(title: new_announcement.title, content: new_announcement.content)).to exist
      end

      it 'responds with the created announcement' do
        assert_select 'announcement' do
          assert_select 'id',      /\d+/
          assert_select 'title',   new_announcement.title
          assert_select 'content', new_announcement.content
        end
      end
    end

    context 'with invalid params' do
      let(:invalid_announcement_xml) do
        <<~XML
          <announcement>
            <title>My announcement</title>
            <content></content>
          </announcement>
        XML
      end

      subject! { post :create, params: { id: announcement }, body: invalid_announcement_xml, format: :xml }

      it 'returns a with an error' do
        is_expected.to have_http_status(:bad_request)
        assert_select 'status[code=invalid_announcement]' do
          assert_select 'summary', "[\"Content can't be blank\"]"
        end
      end
    end
  end

  describe 'PUT #update' do
    let(:updated_announcement_xml) do
      announcement.title = 'Changed title'
      announcement.to_xml(Announcement::DEFAULT_RENDER_PARAMS)
    end
    let(:invalid_announcement_xml) do
      <<~XML
        <announcement>
          <title/>
          <content>Terms of Service</content>
        </announcement>
      XML
    end

    context 'with valid params' do
      subject! { put :update, params: { id: announcement }, body: updated_announcement_xml, format: :xml }

      it 'updates the requested announcement' do
        expect(announcement.reload.title).to eq('Changed title')
        is_expected.to have_http_status(:success)
      end
    end

    context 'with invalid params' do
      subject! { put :update, params: { id: announcement }, body: invalid_announcement_xml, format: :xml }

      it 'returns an error' do
        is_expected.to have_http_status(:bad_request)
        assert_select 'status[code=invalid_announcement]' do
          assert_select 'summary', "[\"Title can't be blank\"]"
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:announcement) { create(:announcement) }

    subject { delete :destroy, params: { id: announcement }, format: :xml }

    it 'destroys the requested announcement' do
      expect { subject }.to change(Announcement, :count).by(-1)
    end

    it { is_expected.to have_http_status(:success) }
  end
end
