# frozen_string_literal: true
require 'rails_helper'

RSpec.describe HistoryElement do
  describe 'HistoryElement::RequestDeleted' do
    it 'has the correct color' do
      expect(HistoryElement::RequestDeleted.new.color).to eq('red')
    end

    it 'has a correct description' do
      expect(HistoryElement::RequestDeleted.new.description).to eq('Request was deleted')
    end
  end
end
