require 'spec_helper'

module Mongoid
  describe AuditLog do
    before(:all) do
      class ::Product
        include Mongoid::Document
        include Mongoid::AuditLog
        field :name, :type => String
        embeds_many :variants
      end

      class ::Variant
        include Mongoid::Document
        field :sku, :type => String
        embedded_in :product
      end
    end

    after(:all) do
      Object.send(:remove_const, :Product)
      Object.send(:remove_const, :Variant)
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

      it 'saves model attributes' do
        AuditLog.record do
          product = Product.create!(:name => 'Foo bar')
          product.update_attributes(:name => 'Bar baz')
          product.destroy

          product.audit_log_entries.count.should == 3
          product.audit_log_entries.each do |entry|
            entry.model_attributes['name'].should be_present
          end
        end
      end

      it 'saves the modifier if passed' do
        user = User.create!
        AuditLog.record(user) do
          product = Product.create!
          product.audit_log_entries.first.modifier.should == user
        end
      end

      it 'properly unsets recording on failure' do
        expect do
          AuditLog.record do
            raise
          end
        end.to raise_error(Exception)

        AuditLog.recording?.should == false
      end

      it 'properly unsets modifier on failure' do
        user = User.create!
        expect do
          AuditLog.record(user) do
            raise
          end
        end.to raise_error(Exception)

        AuditLog.current_modifier.should == nil
      end
    end

    describe '.disable' do
      it 'can disable recording' do
        AuditLog.record do
          product = Product.create!(:name => 'Foo bar')

          AuditLog.disable do
            product.update_attributes(:name => 'Bar baz')
          end

          product.name.should == 'Bar baz'
          product.audit_log_entries.count.should == 1
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

      context 'create' do
        it 'saves details' do
          product = Product.create!(:name => 'Foo bar')
          entry = product.audit_log_entries.first

          entry.create?.should be_true

          entry.tracked_changes.should == {
            'name' => [nil, 'Foo bar']
          }

          entry.model_attributes.should == {
            '_id' => product.id,
            'name' => 'Foo bar'
          }
        end

        it 'saves embedded creations' do
          product = Product.new(:name => 'Foo bar')
          product.variants.build(sku: 'sku')
          product.save!

          entry = product.audit_log_entries.first

          entry.create?.should be_true

          entry.model_attributes.should == {
            '_id' => product.id,
            'name' => 'Foo bar',
            'variants' => [{ '_id' => product.variants.first.id, 'sku'=>'sku' }]
          }

          entry.tracked_changes.should == {
            'name' => [nil, 'Foo bar'],
            'variants' => [{ 'sku' => [nil, 'sku'] }]
          }
        end
      end

      context 'update' do
        it 'saves details' do
          product = Product.create!(:name => 'Foo bar')
          product.update_attributes(:name => 'Bar baz')
          entry = product.audit_log_entries.desc(:created_at).first

          entry.update?.should be_true
          entry.tracked_changes.should == { 'name' => ['Foo bar', 'Bar baz'] }
        end

        it 'saves embedded updates' do
          product = Product.new(:name => 'Foo bar')
          product.variants.build(sku: 'sku')
          product.save!

          product.name = 'Bar baz'
          product.variants.first.sku = 'newsku'
          product.save!

          entry = product.audit_log_entries.desc(:created_at).first

          entry.update?.should be_true
          entry.tracked_changes.should == {
            'name' => ['Foo bar', 'Bar baz'],
            'variants' => [{ 'sku' => ['sku', 'newsku'] }]
          }
        end

        it 'does not save blank updates' do
          product = Product.create!(:name => 'Foo bar')
          product.update_attributes(:name => 'Foo bar')
          product.audit_log_entries.length.should == 1
        end
      end

      context 'destroy' do
        it 'saves an entry' do
          product = Product.create!(:name => 'Foo bar')
          product.destroy
          entry = product.audit_log_entries.desc(:created_at).first

          entry.destroy?.should be_true
        end
      end
    end
  end
end
