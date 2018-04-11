# frozen_string_literal: true

require 'rails_helper'
require 'pretty_nested_errors'

class Bicycle < ApplicationRecord
  include PrettyNestedErrors

  has_many :wheels, index_errors: true
  accepts_nested_attributes_for :wheels
  nest_errors_for :wheels, by: ->(wheel) { "Wheel: #{wheel.name}" }
  nest_errors_for :wheels_spokes, by: ->(spoke) { "Spoke ##{spoke.number}" }
end

class Wheel < ApplicationRecord
  belongs_to :bicycle
  has_many :spokes, index_errors: true
  accepts_nested_attributes_for :spokes

  validates :name, presence: true
end

class Spoke < ApplicationRecord
  validates :tension, presence: true
  validates :number, presence: true

  belongs_to :wheel
end

RSpec.describe PrettyNestedErrors do
  let(:bicycle) do
    Bicycle.new(
      name: 'My Favorite Bicycle',
      wheels_attributes: [
        { name: nil },
        {
          name:              'Rear wheel',
          spokes_attributes: [
            { tension: nil, number: 1 },
            { tension: 1.34, number: 2 },
            { tension: 1.34, number: 3 },
            { tension: 1.34, number: 4 },
            { tension: 1.34, number: 5 }
          ]
        }
      ]
    )
  end

  before do
    ActiveRecord::Base.connection.create_table(:bicycles) do |t|
      t.string :name
    end

    ActiveRecord::Base.connection.create_table(:wheels) do |t|
      t.string :name
      t.integer :bicycle_id
    end

    ActiveRecord::Base.connection.create_table(:spokes) do |t|
      t.float :tension
      t.integer :number
      t.integer :wheel_id
    end
  end

  after do
    ActiveRecord::Base.connection.drop_table(:spokes)
    ActiveRecord::Base.connection.drop_table(:wheels)
    ActiveRecord::Base.connection.drop_table(:bicycles)
  end

  subject! { bicycle.valid? }

  it { is_expected.to be_falsey }

  it 'generates a nested error hash' do
    expect(bicycle.nested_error_messages).to eq(
      'Wheel: ' => ["Name can't be blank"],
      'Spoke #1' => ["Tension can't be blank"]
    )
  end
end
