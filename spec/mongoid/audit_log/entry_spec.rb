require 'spec_helper'

module Mongoid
  module AuditLog
    describe Entry do
      before(:all) do
        @remember_modifier_class_name = AuditLog.modifier_class_name
        AuditLog.modifier_class_name = 'User'

        class ::Product
          include Mongoid::Document
          include Mongoid::AuditLog
          field :name, :type => String
          embeds_many :variants
        end

        class ::Variant
          include Mongoid::Document
          include Mongoid::AuditLog
          field :sku, :type => String
          embedded_in :product
          embeds_many :options
        end

        class ::Option
          include Mongoid::Document
          include Mongoid::AuditLog
          field :name, :type => String
          embedded_in :variant
        end
      end

      after(:all) do
        AuditLog.modifier_class_name = @remember_modifier_class_name
        Object.send(:remove_const, :Product)
        Object.send(:remove_const, :Variant)
      end

      let(:user) { User.create! }

      describe 'scopes' do
        let!(:create) { Entry.create!(:action => :create, :created_at => 10.minutes.ago) }
        let!(:update) { Entry.create!(:action => :update, :created_at => 5.minutes.ago) }
        let!(:destroy) { Entry.create!(:action => :destroy, :created_at => 1.minutes.ago) }

        describe '.creates' do
          it 'returns actions which are creates' do
            Entry.creates.to_a.should == [create]
          end
        end

        describe '.updates' do
          it 'returns actions which are updates' do
            Entry.updates.to_a.should == [update]
          end
        end

        describe '.destroys' do
          it 'returns actions which are destroys' do
            Entry.destroys.to_a.should == [destroy]
          end
        end

        describe '.newest' do
          it 'sorts with newest first' do
            Entry.newest.to_a.should == [destroy, update, create]
          end
        end
      end

      describe '#valid?' do
        it 'does not override a manually set modifier' do
          entry = Entry.new(:modifier_id => user.id)
          entry.valid?
          entry.modifier.should == user
        end
      end

      describe '#modifier' do
        it 'finds the modifier based on the configured class' do
          entry = Entry.new(:modifier_id => user.id)
          entry.modifier.should == user
        end
      end

      describe '#audited' do
        it 'uses the document path to find embedded documents' do
          product = Product.create!(:name => 'Foo bar')
          variant = product.variants.create!
          option = AuditLog.record { variant.options.create! }

          entry = Entry.desc(:created_at).first
          entry.audited.should == option
        end

        it 'returns nil if the audited info is blank' do
          Entry.new.audited.should be_nil
        end
      end

      describe '#modifier_id=' do
        let(:entry) { Entry.new }

        it "sets the modifier's id" do
          entry.modifier = user
          entry.modifier_id.should == user.id.to_s
        end

        it 'sets the modifier if no id' do
          entry.modifier = 'test'
          entry.modifier_id.should == 'test'
        end
      end

      describe '#respond_to?' do
        let(:entry) do
          Entry.new(:model_attributes => { 'name' => 'foo', 'other' => nil })
        end

        it 'returns true for methods from the model attributes' do
          entry.respond_to?(:name).should be_true
          entry.respond_to?(:other).should be_true
        end
      end

      describe '#method_missing' do
        let(:entry) do
          Entry.new(:model_attributes => { 'name' => 'foo', 'other' => nil })
        end

        it 'responds to methods for which it has a model attribute' do
          entry.name.should == 'foo'
          entry.other.should == nil
        end
      end

      describe '#root' do
        it 'returns nil if cannot be found' do
          product = Product.create!(:name => 'Foo bar')
          AuditLog.record { product.variants.create! }

          entry = Entry.desc(:created_at).first
          product.destroy
          entry.root.should be_nil
        end
      end
    end
  end
end
