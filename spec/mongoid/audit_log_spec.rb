require 'spec_helper'

module Mongoid
  describe AuditLog do
    before(:all) do
      class ::Product
        include Mongoid::Document
        include Mongoid::AuditLog

        field :name, :type => String
      end
    end

    after(:all) do
      Object.send(:remove_const, :Product)
    end

    describe '.record' do
      it 'does not save an entry if not recording' do
        product = Product.create!
        product.audit_log_entries.should be_empty
      end

      it 'saves create entries' do
        AuditLog.record do
          product = Product.create!
          product.audit_log_entries.count.should == 1
        end
      end

      it 'saves update entries' do
        AuditLog.record do
          product = Product.create!(:name => 'Foo bar')
          2.times { |i| product.update_attributes(:name => "Test #{i}") }
          product.audit_log_entries.count.should == 3
        end
      end

      it 'saves destroy entries' do
        AuditLog.record do
          product = Product.create!
          product.destroy
          AuditLog::Entry.count.should == 2
        end
      end

      it 'saves the modifier if passed' do
        user = User.create!
        AuditLog.record(user) do
          product = Product.create!
          product.audit_log_entries.first.modifier.should == user
        end
      end
    end

    describe 'callbacks' do
      let(:user) { User.create! }

      around(:each) do |example|
        AuditLog.record(user) do
          example.run
        end
      end

      it 'saves details on an entry on create' do
        product = Product.create!(:name => 'Foo bar')
        entry = product.audit_log_entries.first

        entry.is_create?.should be_true
        entry.tracked_changes.should == { 'name' => [nil, 'Foo bar'] }
      end

      it 'saves details on an update' do
        product = Product.create!(:name => 'Foo bar')
        product.update_attributes(:name => 'Bar baz')
        entry = product.audit_log_entries.last

        entry.is_update?.should be_true
        entry.tracked_changes.should == { 'name' => ['Foo bar', 'Bar baz'] }
      end

      it 'saves details on a destroy' do
        product = Product.create!(:name => 'Foo bar')
        product.destroy
        entry = product.audit_log_entries.last

        entry.is_destroy?.should be_true
      end
    end
  end
end
