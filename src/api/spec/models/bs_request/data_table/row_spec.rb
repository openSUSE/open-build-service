# frozen_string_literal: true
require 'rails_helper'

RSpec.describe BsRequest::DataTable::Row do
  let!(:user) { create(:confirmed_user, login: 'moi') }
  let(:request) { create(:bs_request) }
  let(:row) { BsRequest::DataTable::Row .new(request) }

  describe '#created_at' do
    it { expect(row.created_at).to eq(request.created_at) }
  end

  describe '#priority' do
    it { expect(row.priority).to eq(request.priority) }
  end

  describe '#number' do
    it { expect(row.number).to eq(request.number) }
  end

  describe '#creator' do
    it { expect(row.creator).to eq(request.creator) }
  end
end
