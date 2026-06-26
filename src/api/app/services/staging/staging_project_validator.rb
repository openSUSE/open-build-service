module Staging
  class StagingProjectValidator
    attr_reader :errors

    def initialize(project)
      @project = project
    end

    def call
      check_errors if authorized?
      self
    end

    def valid?
      @errors.nil?
    end

    private

    def authorized?
      return can_create? if @project.new_record?

      can_update?
    end

    def can_create?
      return true if ProjectPolicy.new(User.possibly_nobody, @project).create?

      @errors = "Project \"#{@project}\": you are not allowed to create this project."
      false
    end

    def can_update?
      return true if ProjectPolicy.new(User.possibly_nobody, @project).update?

      @errors = "Project \"#{@project}\": you are not allowed to use this project."
      false
    end

    def check_errors
      @errors = "Project \"#{@project}\": has a staging already. Nested stagings are not supported." if @project.staging
      @errors = "Project \"#{@project}\": is already assigned to a staging workflow." if @project.staging_workflow_id?
      @errors = "Project \"#{@project}\": #{@project.errors.full_messages.to_sentence}." unless @project.valid?
    end
  end
end
