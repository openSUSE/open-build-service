class GroupFilterChoicesPresenter
  attr_reader :choices

  def initialize
    @choices = groups_for_filter
  end

  def selected
    choices.keys.last
  end

  private

  def groups_for_filter
    {
      'Viva Belgrado' => 3,
      'Boïra' => 2,
      'Jardin de la Croix' => 1
    }
  end
end
