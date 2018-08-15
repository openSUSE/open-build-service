FactoryBot.define do
  factory :status_history do
    transient do
      source { 'source' }
      architecture { 'x86_64' }
      range { 0..0 }
    end

    key { "#{source}_#{architecture}" }
    time { Random.rand(0..365).days.ago.to_i }
    value { Random.rand(range) }
  end
end
