module Mongoid
  module AuditLog
    class EmbeddedChanges
      attr_reader :model

      def initialize(model)
        @model = model
      end

      def relations
        model.relations.inject({}) do |memo, t|
          name, relation = *t
          memo[name] = relation if relation.macro.in?(:embeds_one, :embeds_many)
          memo
        end
      end

      def all
        @all ||= relations.inject({}) do |memo, t|
          name = t.first
          embedded = model.send(name)
          changes = Mongoid::AuditLog::Changes.extract_from(embedded)

          if embedded.present? && changes.present?
            memo[name] = changes
          end

          memo
        end
      end
    end
  end
end
