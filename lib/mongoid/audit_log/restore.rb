module Mongoid
  module AuditLog
    class Restore
      class DuplicateError < StandardError; end
      class InvalidRestore < StandardError; end

      attr_reader :entry
      delegate :name, to: :restored
      delegate :for_embedded_doc?, to: :entry

      def initialize(entry)
        @entry = entry
      end

      def valid?
        !entry.for_embedded_doc? || restored_root.present?
      end

      def perform
        restored.attributes = attributes
        restored.save!
      end

      def attributes
        @attributes ||=
          begin
            attrs = entry.model_attributes.deep_dup
            restored.send(:process_localized_attributes, model_class, attrs)
            attrs
          end
      end

      def model_class
        entry.audited_type.constantize
      end

      def restored
        @restored ||=
          if entry.for_embedded_doc?
            find_embedded_restored
          else
            find_root_restored
          end
      end

      def find_root_restored
        model_class.new
      end

      def find_embedded_restored
        raise InvalidRestore if restored_root.blank?

        last_path = document_path.last
        metadata = restored_root.class.reflect_on_association(last_path['relation'])
        relation = restored_root.send(last_path['relation'])

        if metadata.many?
          relation.build
        elsif relation.present?
          raise DuplicateError
        else
          restored_root.send("build_#{metadata.name}")
        end
      end

      def restored_root
        document_path.reduce(entry.root) do |current, path|
          match = if document_path_matches?(path, current)
                    current
                  elsif current.respond_to?(:detect)
                    current.detect do |model|
                      document_path_matches?(path, model)
                    end
                  end

          if path == document_path.last
            return match
          else
            match.send(path['relation'])
          end
        end
      end

      def document_path
        # don't need last because that entry represents the deleted doc
        entry.document_path[0..-2]
      end

      def document_path_matches?(path, object)
        object.class.name == path['class_name'] && object.id == path['id']
      end
    end
  end
end
