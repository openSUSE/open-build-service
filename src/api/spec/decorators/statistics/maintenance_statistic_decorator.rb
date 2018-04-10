# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Statistics::MaintenanceStatisticDecorator do
  describe '#to_hash_for_xml' do
    let(:maintenance_statistic1) do
      double(
        type: :issue_created,
        name: Faker::Lorem.word,
        tracker: Faker::Lorem.word,
        when: Faker::Date.forward(10)
      )
    end
    let(:expected_xml_hash1) do
      {
        type:    maintenance_statistic1.type,
        name:    maintenance_statistic1.name,
        tracker: maintenance_statistic1.tracker,
        when:    maintenance_statistic1.when
      }
    end
    let(:maintenance_statistic2) do
      double(
        type: :review_accepted,
        who: Faker::Lorem.word,
        id: rand(100),
        when: Faker::Date.forward(10)
      )
    end
    let(:expected_xml_hash2) do
      {
        type: maintenance_statistic2.type,
        who:  maintenance_statistic2.who,
        id:   maintenance_statistic2.id,
        when: maintenance_statistic2.when
      }
    end
    let(:expected_xml_hash3) do
      {
        type: maintenance_statistic3.type,
        when: maintenance_statistic3.when
      }
    end

    let(:test_data) do
      {
        maintenance_statistic1 => expected_xml_hash1,
        maintenance_statistic2 => expected_xml_hash2
      }
    end

    it 'generates a hash for the xml view' do
      test_data.each do |maintenance_statistic, xml_hash|
        decorated = Statistics::MaintenanceStatisticDecorator.new(maintenance_statistic)

        expect(decorated.to_hash_for_xml).to eq(xml_hash)
      end
    end
  end
end
