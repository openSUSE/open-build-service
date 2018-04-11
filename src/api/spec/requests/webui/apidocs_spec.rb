# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Apidocs', type: :request do
  it 'Redirects /apidocs to /apidocs/index' do
    get '/apidocs'
    expect(response).to redirect_to(apidocs_index_path)
  end
end
