FactoryBot.define do
  factory :flag do
    project
    position 1
    status 'enable'

    factory :useforbuild_flag do
      flag 'useforbuild'
    end

    factory :sourceaccess_flag do
      flag 'sourceaccess'
      status 'disable'
    end

    factory :binarydownload_flag do
      flag 'binarydownload'
    end

    factory :debuginfo_flag do
      flag 'debuginfo'
    end

    factory :build_flag do
      flag 'build'
    end

    factory :publish_flag do
      flag 'publish'
    end

    factory :access_flag do
      flag 'access'
    end

    factory :lock_flag do
      flag 'lock'
    end
  end
end
