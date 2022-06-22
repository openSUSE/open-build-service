require 'rails_helper'

RSpec.describe DeleteConfirmationDialogComponent, type: :component do
  it 'fails when modal_id is not passed' do
    expect { render_inline(described_class.new(method: :put)) }.to raise_error(ArgumentError, 'missing keyword: :modal_id')
  end

  it 'fails when method is not passed' do
    expect { render_inline(described_class.new(modal_id: 'delete-spec-modal')) }.to raise_error(ArgumentError, 'missing keyword: :method')
  end

  it 'contains all the default values when options are not passed' do
    expect(render_inline(described_class.new(modal_id: 'delete-spec-modal', method: :put))).to have_text('Do you really want to remove this item?')
  end

  it 'contains the values specifically passed' do
    expect(render_inline(described_class.new(modal_id: 'delete-spec-modal', method: :put, options: {
                                               modal_title: 'Do you really want to remove this project from the watchlist?'
                                             }))).to have_text('Do you really want to remove this project from the watchlist?')
  end
end
