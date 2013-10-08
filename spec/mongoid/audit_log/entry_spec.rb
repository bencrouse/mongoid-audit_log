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
        end
      end

      after(:all) do
        AuditLog.modifier_class_name = @remember_modifier_class_name
        Object.send(:remove_const, :Product)
      end

      let(:user) { User.create! }

      describe '#modifier' do
        it 'finds the modifier based on the configured class' do
          entry = Entry.new(:modifier_id => user.id)
          entry.modifier.should == user
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
    end
  end
end
