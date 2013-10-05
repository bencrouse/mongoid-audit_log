require "mongoid/audit_log/version"
require "mongoid/audit_log/entry"

module Mongoid
  module AuditLog
    extend ActiveSupport::Concern

    included do
      has_many :audit_log_entries, :as => :audited,
                                   :class_name => 'Mongoid::AuditLog::Entry'

      [:create, :update, :destroy].each do |action|
        send("before_#{action}") { prepare_audit_log_entry(action) if Mongoid::AuditLog.recording? }
        send("after_#{action}") { save_audit_log_entry(action) if Mongoid::AuditLog.recording? }
      end
    end

    mattr_accessor :modifier_class_name
    self.modifier_class_name = 'User'

    def self.record(modifier = nil)
      Thread.current[:mongoid_audit_log_recording] = true
      Thread.current[:mongoid_audit_log_modifier] = modifier
      yield
      Thread.current[:mongoid_audit_log_recording] = nil
      Thread.current[:mongoid_audit_log_modifier] = nil
    end

    def self.recording?
      !!Thread.current[:mongoid_audit_log_recording]
    end

    def self.current_modifier
      Thread.current[:mongoid_audit_log_modifier]
    end

  private

    def prepare_audit_log_entry(type)
      @_audit_log_changes = changes.except('_id')
    end

    def save_audit_log_entry(type)
      if type == :destroy
        Mongoid::AuditLog::Entry.create!(
          :audited_type => self.class,
          :audited_id => id,
          :is_destroy => true,
          :modifier => Mongoid::AuditLog.current_modifier
        )
      else
        audit_log_entries.create!(
          :is_create => type == :create,
          :is_update => type == :update,
          :tracked_changes => @_audit_log_changes,
          :modifier => Mongoid::AuditLog.current_modifier
        )
      end
    end
  end
end
