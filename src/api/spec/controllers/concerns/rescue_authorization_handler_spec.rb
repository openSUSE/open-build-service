require 'rails_helper'

class FakeObject; end # rubocop:disable Lint/EmptyClass

class FakePolicy < ApplicationPolicy
  def index?
    false
  end
end

# rubocop:disable RSpec/FilePath
RSpec.describe ApplicationController do
  let(:user) { create(:confirmed_user) }

  controller do
    def index
      authorize FakeObject.new, policy_class: FakePolicy
    end
  end

  describe '#rescue_from' do
    context 'in html format' do
      before do
        login user
        get :index, format: :html
      end

      describe 'returns html' do
        it { expect(flash[:error]).to eq('Sorry, you are not authorized to list this fake object.') }
      end
    end

    context 'in json format' do
      before do
        login user
        get :index, format: :json
      end

      describe 'returns json' do
        it { expect(response).to have_http_status(:forbidden) }
        it { expect(response.parsed_body['errorcode']).to eq('list_fake_object_not_authorized') }
      end
    end

    context 'any other format' do
      before do
        login user
        get :index, format: ''
      end

      describe 'returns XML' do
        it { expect(response).to have_http_status(:forbidden) }
        it { expect(response).to render_template(:status) }
      end
    end
  end
end
# rubocop:enable RSpec/FilePath
