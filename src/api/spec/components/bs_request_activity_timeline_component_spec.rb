require 'rails_helper'

RSpec.describe BsRequestActivityTimelineComponent, type: :component do
  context 'when we provide a bs_request' do
    it 'shows an element telling who created the request and when'
    it 'shows the comments threads'
    it 'shows the history elements'
  end

  context 'when we do not provide a bs_request' do
    it 'raises an error warning the user to provide a request'
  end
end
