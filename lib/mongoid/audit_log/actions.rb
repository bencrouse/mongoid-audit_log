module Mongoid
  module AuditLog
    mattr_accessor :actions
    self.actions = [:create, :update, :destroy]
  end
end
