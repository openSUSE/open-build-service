class AllowedUserValidator < ActiveModel::Validator
  def validate(record)
    # NOTE: it could be more generic and check 'locked' users or other possible banned ones
    record.errors.add(:base, "Couldn't find user #{record.user.login}") if record.user && record.user.nobody?
  end
end
