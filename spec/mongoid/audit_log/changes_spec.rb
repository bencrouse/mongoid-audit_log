require 'spec_helper'

module Mongoid
  module AuditLog
    describe Changes do
      before(:all) do
        class ::Product
          include Mongoid::Document
          include Mongoid::AuditLog
          include Mongoid::Timestamps
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

      describe '.extract_from' do
        context 'enumerable' do
          it 'returns mapped changes' do
            models = Array.new(3) { Product.new(name: rand) }
            results = Changes.extract_from(models)

            results.length.should == 3
          end
        end
      end

      describe '.clean_fields' do
        it 'removes the fields from change hashes' do
          changes = { "_id" => [nil, "52509662ace6ecd79a000009"], "name" => [nil, "Foo bar"] }
          results = Changes.clean_fields('_id', from: changes)
          results.should == { "name" => [nil, "Foo bar"] }
        end
      end

      describe '#all' do
        let(:product) do
          product = Product.new(:name => 'Foo bar')
          product.variants.build(sku: 'sku1')
          product.variants.build(sku: 'sku2')
          product
        end

        let(:changes) do
          Changes.new(product).all
        end

        it 'is empty if the model is nil' do
          Changes.new(nil).all.should == {}
        end

        it 'has model changes' do
          changes['name'].should == [nil, 'Foo bar']
        end

        it 'has embedded model changes' do
          changes['variants'].should == [
            { "sku" => [nil, "sku1"] },
            { "sku" => [nil, "sku2"] }
          ]
        end

        it 'is blank if only an ignored field is changed' do
          product.save!
          product.updated_at = 1.hour.from_now

          changes.should_not be_present
        end

        it 'has changes if only the embedded model changes' do
          product.save!
          product.variants.first.sku = 'newsku'

          changes.should == {
            "variants"=> [{ "sku" =>[ "sku1", "newsku"] }]
          }
        end
      end

      describe '#present?' do
        it 'is false if no embedded models have changed' do
          product = Product.new(:name => 'Foo bar')
          product.variants.build(sku: 'sku1')
          product.variants.build(sku: 'sku2')
          product.save!

          Changes.new(product).should_not be_present
        end
      end
    end
  end
end
