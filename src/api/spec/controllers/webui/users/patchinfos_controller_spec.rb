require 'rails_helper'

RSpec.describe Webui::Users::PatchinfosController do
  describe 'GET #index' do
    it_behaves_like 'require logged in user' do
      let(:method) { :get }
      let(:action) { :index }
    end
  end
end
