# This is a model class to represent dogs and is an example of how they have to
# be structured for a better comprehension
class Dog < ApplicationRecord
  #### Includes and extends
  include AnimalSystems
  include ActiveModel::AttributeMethods

  #### Constants
  NUMBER_OF_LEGS = 4
  NUMBER_OF_QUEUES = 1
  NUMBER_OF_EYES = 2
  POSSIBLE_COLORS = ['white', 'black', 'brown', 'vanilla', 'chocolate', 'dotted'].freeze

  #### Self config
  self.table_name = 'OBS_dogs'

  #### Attributes
  attr_accessor :number_of_barks
  attribute_method_prefix 'reset_'

  alias_method :go_home, :save
  alias_method :go_home!, :save!

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :owner, class_name: 'Person'
  belongs_to :herd
  belongs_to :house
  has_one :prefered_person, class_name: 'Person'
  has_many :places_to_pee, class_name: 'Place'
  has_many :places_to_sleep, through: :house

  #### Callbacks macros: before_save, after_save, etc.
  before_destroy :bark
  after_destroy :cry

  #### Scopes (first the default_scope macro if is used)
  default_scope where(alive: true)
  scope :blacks, -> { where(color: 'brown') }
  scope :deads, -> { rewhere(alive: false) }

  #### Validations macros
  validates :name, :color, pressence: true

  #### Class methods using self. (public and then private)
  #### To define class methods as private use private_class_method
  def self.born!(attributes)
    say("It's alive!")
    dog = new(attributes)
    dog.alive = true
    dog.save!
    dog.cry
    dog
  end

  def self.killall_by(attributes = {})
    say('Die!')
    where(attributes).each(&:kill)
  end

  def self.call_all
    say('Fiuuiuuuu!')
    all.each(&:bark)
  end

  #### private

  def self.say(string)
    puts "[Dog's Master] >> #{string}"
  end

  private_class_method :say

  #### Instance methods (public and then protected/private)
  def initialize(attributes = {})
    super
    @number_of_barks = 0
  end

  def bark
    say('Guau!')
    @number_of_barks += 1
  end

  def cry
    say('Iiiiii Iiii Iiiii!!')
  end

  protected

  def say(string)
    puts "[#{name}] >> #{string}"
  end

  private

  def reset_attribute(attribute)
    send("#{attribute}=", 0)
  end
end
