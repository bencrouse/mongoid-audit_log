require "mongoid/audit_log/version"
require "mongoid/audit_log/config"
require "mongoid/audit_log/entry"
require "mongoid/audit_log/changes"
require "mongoid/audit_log/restore"

module Mongoid
  module AuditLog
    extend ActiveSupport::Concern

    included do
      has_many :audit_log_entries, :as => :audited,
        :class_name => 'Mongoid::AuditLog::Entry', :validate => false

      AuditLog.actions.each do |action|
        send("before_#{action}") do
          set_audit_log_changes if record_audit_log?
        end

        send("after_#{action}") do
          save_audit_log_entry(action) if record_audit_log?
        end
      end
    end

    class_methods do
      def enable_audit_log
        @audit_log_enabled = true
      end

      def disable_audit_log
        @audit_log_enabled = false
      end

      def audit_log_enabled?
        !defined?(@audit_log_enabled) || @audit_log_enabled
      end
    end

    def self.record(modifier = nil)
      already_recording = recording?
      enable unless already_recording
      self.current_modifier = modifier
      yield
    ensure
      disable unless already_recording
      self.current_modifier = nil
    end

    def self.enable
      Thread.current[:mongoid_audit_log_recording] = true
    end

    def self.disable
      already_recording = recording?
      Thread.current[:mongoid_audit_log_recording] = false

      if block_given?
        begin
          yield
        ensure
          Thread.current[:mongoid_audit_log_recording] = already_recording
        end
      end
    end

    def self.recording?
      !!Thread.current[:mongoid_audit_log_recording]
    end

    def self.current_modifier
      Thread.current[:mongoid_audit_log_modifier]
    end

    def self.current_modifier=(modifier)
      Thread.current[:mongoid_audit_log_modifier] = modifier
    end

    def record_audit_log?
      AuditLog.recording? && self.class.audit_log_enabled?
    end

    private

    def set_audit_log_changes
      @_audit_log_changes = Changes.new(self).tap(&:read)
    end

    def save_audit_log_entry(action)
      unless action == :update && @_audit_log_changes.all.blank?
        Entry.create!(
          :action => action,
          :audited_type => self.class,
          :audited_id => id,
          :tracked_changes => @_audit_log_changes.all,
          :model_attributes => attributes.deep_dup,
          :document_path => traverse_association_chain
        )
      end
    end

    def traverse_association_chain(node = self, current_relation = nil)
      relation = node.embedded? ? node.association_name.to_s : nil
      list = node._parent ? traverse_association_chain(node._parent, relation) : []
      list << { class_name: node.class.name, id: node.id, relation: current_relation }
      list
    end
  end
end
