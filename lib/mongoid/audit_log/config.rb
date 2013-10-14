module Mongoid
  module AuditLog
    mattr_accessor :actions
    self.actions = [:create, :update, :destroy]

    mattr_accessor :modifier_class_name
    self.modifier_class_name = 'User'

    mattr_accessor :cache_fields
    self.cache_fields = []
  end
end
