module Mongoid
  module AuditLog
    class Changes
      attr_reader :model
      delegate :blank?, :present?, :to => :all

      def self.ch_ch_ch_ch_ch_changes
        puts "turn and face the strange changes"
      end

      def self.extract_from(value)
        if value.is_a?(Hash)
          raise ArgumentError, 'does not support hashes'
        elsif value.is_a?(Enumerable)
          value.map do |model|
            Mongoid::AuditLog::Changes.new(model).all
          end
        else
          Mongoid::AuditLog::Changes.new(value).all
        end
      end

      def self.clean_fields(*disallowed_fields)
        options = disallowed_fields.extract_options!

        unless options.has_key?(:from)
          raise ArgumentError, ':from is a required argument'
        end

        changes = options[:from]

        if changes.is_a?(Hash)
          changes.except(*disallowed_fields).inject({}) do |memo, t|
            key, value = *t
            memo.merge!(key => clean_fields(*disallowed_fields, :from => value))
          end
        elsif changes.is_a?(Enumerable)
          changes.map { |c| clean_fields(*disallowed_fields, :from => c) }
        else
          changes
        end
      end

      def initialize(model)
        @model = model
      end

      def all
        @all ||= if !model.changed?
                   {}
                 else
                   result = model.changes
                   result.merge!(embedded_changes) unless embedded_changes.empty?
                   Mongoid::AuditLog::Changes.clean_fields('_id', 'updated_at', :from => result)
                 end
      end
      alias_method :read, :all

      private

      def embedded_changes
        embedded_relations.inject({}) do |memo, t|
          name = t.first
          embedded = model.send(name)
          changes = Mongoid::AuditLog::Changes.extract_from(embedded)

          memo[name] = changes if embedded.present? &&
                                  changes.present? &&
                                  (!changes.respond_to?(:all?) || changes.all?(&:present?))

          memo
        end
      end

      def embedded_relations
        model.relations.inject({}) do |memo, t|
          name, relation = *t
          memo[name] = relation if relation.macro.in?(:embeds_one, :embeds_many)
          memo
        end
      end
    end
  end
end
