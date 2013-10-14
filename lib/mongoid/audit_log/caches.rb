module Mongoid
  module AuditLog
    class Caches
      attr_reader :model

      def initialize(model)
        @model = model
      end

      def all
        return nil unless Mongoid::AuditLog.cache_fields.present?

        Mongoid::AuditLog.cache_fields.inject({}) do |memo, field|
          memo[field] = model.send(field) if model.respond_to?(field)
          memo
        end
      end
    end
  end
end
