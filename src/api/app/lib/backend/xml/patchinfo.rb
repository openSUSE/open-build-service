require 'mail'

module Backend::Xml
  class Patchinfo
    include HappyMapper

    attribute :incident, Integer
    attribute :version, String

    has_one :category, String
    has_one :rating, String
    has_one :name, String
    has_one :summary, String
    has_one :description, String
    has_one :message, String
    has_one :swampid, Integer
    has_one :packager, String
    has_one :retracted, TrueClass
    has_one :stopped, TrueClass
    has_one :zypp_restart_needed, TrueClass
    has_one :reboot_needed, TrueClass
    has_one :relogin_needed, TrueClass

    has_many :packages, String, tag: 'package'
    has_many :binaries, String, tag: 'binary'
    has_many :releasetargets, Backend::Xml::Patchinfo::Releasetarget, tag: 'releasetarget'
    has_many :issues, Backend::Xml::Patchinfo::Issue, tag: 'issue'

    def packager_object
      User.find_by(login: packager) || User.find_by(email: Mail::Address.new(packager).address)
    end
  end
end
