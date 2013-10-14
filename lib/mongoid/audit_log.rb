require "mongoid/audit_log/version"
require "mongoid/audit_log/config"
require "mongoid/audit_log/entry"
require "mongoid/audit_log/caches"
require "mongoid/audit_log/changes"
require "mongoid/audit_log/embedded_changes"

module Mongoid
  module AuditLog
    extend ActiveSupport::Concern

    included do
      has_many :audit_log_entries, :as => :audited,
        :class_name => 'Mongoid::AuditLog::Entry', :validate => false

      Mongoid::AuditLog.actions.each do |action|
        send("before_#{action}") do
          set_audit_log_changes if Mongoid::AuditLog.recording?
        end

        send("after_#{action}") do
          save_audit_log_entry(action) if Mongoid::AuditLog.recording?
        end
      end
    end

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

    def set_audit_log_changes
      @_audit_log_changes = Mongoid::AuditLog::Changes.new(self).tap(&:read)
    end

    def save_audit_log_entry(action)
      unless action == :update && @_audit_log_changes.all.blank?
        Mongoid::AuditLog::Entry.create!(
          :action => action,
          :audited_type => self.class,
          :audited_id => id,
          :tracked_changes => @_audit_log_changes.all,
          :caches => Mongoid::AuditLog::Caches.new(self).all
        )
      end
    end
  end
end
