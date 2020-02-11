# Mongoid::AuditLog

Frustrated with the other options for this, I wrote this gem to handle most basic audit logging for Mongoid. It is intended to be stupidly simple, and offers no fancy functionality.

## Installation

Add this line to your application's Gemfile:

    gem 'mongoid-audit_log'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mongoid-audit_log

## Usage

### Recording Activity

Include the `Mongoid::AuditLog` module into your model.

```ruby
class Model
  include Mongoid::Document
  include Mongoid::AuditLog
  field :name
end
```

This will not enable logging by itself, only changes made within the block passed to the record method will be saved.

```ruby
Mongoid::AuditLog.record do
  Model.create!
end
```

If you want to log the user who made the change, pass that user to the record method:

```ruby
Mongoid::AuditLog.record(current_user) do
  Model.create!
end

# or

Mongoid::AuditLog.current_modifier = current_user
Mongoid::AuditLog.enable
```

A basic implementation in a Rails app might look something like:

```ruby
class ApplicationController < ActionController::Base
  around_filter :audit_log

  def current_user
    @current_user ||= User.find(session[:user_id])
  end

  private

  def audit_log
    Mongoid::AuditLog.record(current_user) do
      yield
    end
  end
end
```

### Viewing Activity

When an audited model is changed, it will create a record of the `Mongoid::AuditLog::Entry` class.
Each class responds to some query methods:

```ruby
Mongoid::AuditLog.record do
  model = Model.create!
  module.update_attributes(:name => 'model')
end

model.audit_log_entries.length == 2 # => true

model.audit_log_entries.first.create? # => true
model.audit_log_entries.first.update? # => false
model.audit_log_entries.first.destroy? # => false

model.audit_log_entries.second.create? # => false
model.audit_log_entries.second.update? # => true
model.audit_log_entries.second.destroy? # => false

# And on update you have the tracked changes
model.audit_log_entries.second.tracked_changes.should == { 'name' => [nil, 'model'] }
```

There are also some built-in scopes (examples from the tests):

```ruby
  create = Entry.create!(:action => :create, :created_at => 10.minutes.ago)
  update = Entry.create!(:action => :update, :created_at => 5.minutes.ago)
  destroy = Entry.create!(:action => :destroy, :created_at => 1.minutes.ago)

  Entry.creates.to_a.should == [create]
  Entry.updates.to_a.should == [update]
  Entry.destroys.to_a.should == [destroy]
  Entry.newest.to_a.should == [destroy, update, create]
end
```

### Additional saved data

You can access the attributes of the model saved on the `Mongoid::AuditLog::Entry`.
They are saved on the document in the `#model_attributes`, and include any changes in
the `#tracked_changes` hash.

Examples:
```ruby
Mongoid::AuditLog.record do
  model = Model.create!(:name => 'foo bar')
end

model.audit_log_entries.length == 1 # => true

model.audit_log_entries.first.create? # => true
model.audit_log_entries.first.model_attributes # => {"name"=>"foo bar"}
```

### Restoring

You can restore models for `Mongoid::AuditLog::Entry` instances for deletions.
This works for both root and embedded documents.

Examples:
```ruby
model = Model.create!(:name => 'foo bar')
Mongoid::AuditLog.record { model.destroy }

entry = Mongoid::AuditLog::Entry.first
entry.restore!

model == Model.find_by(name: 'foo bar') # => true
```

It's possible to end up in a situation where a destroy entry cannot be restored, e.g. an entry deleting an embedded document for a root document that's already been deleted. In these scenarios, `Mongoid::AuditLog::Restore::InvalidRestore` will be raised.

### Disabling

The `AuditLog` module provides methods to included classes to allow explicit disabling or enabling of logging. This can be useful if a model includes the mixin indirectly through another mixin or inheritance.

```ruby
class Parent
  include Mongoid::Document
  include Mongoid::AuditLog
end

class Child < Parent
  disable_audit_log
end

class Grandchild < Child
  enable_audit_log
end

Parent.audit_log_enabled? # => true
Child.audit_log_enabled? # => false
Grandchild.audit_log_enabled? # => true
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
