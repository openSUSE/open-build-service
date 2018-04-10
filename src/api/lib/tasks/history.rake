# frozen_string_literal: true

namespace :db do
  namespace :history do
    desc 'Rescale old status histories'
    task rescale: :environment do
      StatusHistory.first.rescale
    end
  end
end
