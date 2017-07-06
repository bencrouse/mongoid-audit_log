require 'spec_helper'

module Mongoid
  module AuditLog
    describe Restore do
      before(:all) do
        class ::First
          include Mongoid::Document
          include Mongoid::AuditLog

          field :name, type: String, localize: true
          embeds_many :seconds
        end

        class ::Second
          include Mongoid::Document
          include Mongoid::AuditLog

          field :name, type: String, localize: true
          embedded_in :first
          embeds_many :thirds
        end

        class ::Third
          include Mongoid::Document
          include Mongoid::AuditLog

          field :name, type: String, localize: true
          embedded_in :second
        end
      end

      after(:all) do
        [:First, :Second, :Third].each { |c| Object.send(:remove_const, c) }
      end

      describe '.perform' do
        it 'restores a root document' do
          root = First.create!(name: 'Foo')
          Mongoid::AuditLog.record { root.destroy }
          restore = Restore.new(Mongoid::AuditLog::Entry.first)
          restore.perform

          restore.restored.should be_persisted
          First.count.should == 1
          restore.restored.should == First.first
          restore.restored.name.should == 'Foo'
        end

        it 'restores an embedded array document' do
          root = First.create!(name: 'Foo', seconds: [{ name: 'Bar' }])
          Mongoid::AuditLog.record { root.seconds.first.destroy }
          restore = Restore.new(Mongoid::AuditLog::Entry.first)
          restore.perform
          root.reload

          restore.restored.should be_persisted
          root.seconds.length.should == 1
          root.seconds.first.should == restore.restored
          root.seconds.first.name.should == 'Bar'
        end

        it 'restores a nested array document' do
          root = First.create!(
            name: 'Foo',
            seconds: [{ name: 'Bar', thirds: [{ name: 'Baz' }] }]
          )
          Mongoid::AuditLog.record { root.seconds.first.thirds.first.destroy }
          restore = Restore.new(Mongoid::AuditLog::Entry.first)
          restore.perform
          root.reload

          restore.restored.should be_persisted
          root.seconds.first.thirds.length.should == 1
          root.seconds.first.thirds.first.should == restore.restored
          root.seconds.first.thirds.first.name.should == 'Baz'
        end
      end
    end
  end
end
