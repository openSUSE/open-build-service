Flipper.configure do
  # Register beta and rollout groups by default.
  # We need to add it when initializing because Flipper.register doesn't
  # store anything in database.

  Flipper.register(:staff) do |user|
    user.respond_to?(:is_staff?) && user.is_staff?
  end

  Flipper.register(:beta) do |user|
    user.respond_to?(:in_beta?) && user.in_beta?
  end

  Flipper.register(:rollout) do |user|
    user.respond_to?(:in_rollout?) && user.in_rollout?
  end
end
