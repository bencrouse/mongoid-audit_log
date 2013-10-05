module Mongoid
  module AuditLog
    class Entry
      include Mongoid::Document
      include Mongoid::Timestamps::Created

      field :is_create, :type => Boolean, :default => false
      field :is_update, :type => Boolean, :default => false
      field :is_destroy, :type => Boolean, :default => false
      field :tracked_changes, :type => Hash, :default => {}
      field :modifier_id, :type => String

      belongs_to :audited, :polymorphic => true, :index => true

      index({ :modifier_id => 1 })

      def modifier
        @modifier ||= if modifier_id.blank?
                        nil
                      else
                        klass = Mongoid::AuditLog.modifier_class_name.constantize
                        klass.find(modifier_id)
                      end
      end

      def modifier=(modifier)
        self.modifier_id = if modifier.present? && modifier.respond_to?(:id)
                             modifier.id
                           else
                             modifier
                           end

        @modifier = modifier
      end
    end
  end
end
