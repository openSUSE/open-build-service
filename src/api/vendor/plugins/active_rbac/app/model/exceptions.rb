# The RecursionInTree exception is thrown when a group's or role's descendant
# is assigned as parent.
class RecursionInTree < ActiveRecord::ActiveRecordError 
end

# The CantDeleteWithChildren exception is thrown when a group or role 
# that still has children is to be destroyed.
class CantDeleteWithChildren < ActiveRecord::ActiveRecordError
end

# The MultipleRegistration exception is thrown when create_user_registration
# is called on a User instance that already has a user_registration record
# assigned.
class MultipleRegistrationTokens < ActiveRecord::ActiveRecordError
end