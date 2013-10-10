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

model.audit_log_entries.length == 2

model.audit_log_entries.first.create? # => true
model.audit_log_entries.first.update? # => false
model.audit_log_entries.first.destroy? # => false

model.audit_log_entries.second.create? # => false
model.audit_log_entries.second.update? # => update
model.audit_log_entries.second.destroy? # => false

# And on update you have the tracked changes
model.audit_log_entries.second.tracked_changes.should == { 'name' => [nil, 'model'] }
```

There are also some built-in scopes (from the tests):

```ruby
  create = Entry.create!(:action => :create, :created_at => 10.minutes.ago) }
  update = Entry.create!(:action => :update, :created_at => 5.minutes.ago) }
  destroy = Entry.create!(:action => :destroy, :created_at => 1.minutes.ago) }

  Entry.creates.to_a.should == [create]
  Entry.updates.to_a.should == [update]
  Entry.destroys.to_a.should == [destroy]
  Entry.newest.to_a.should == [destroy, update, create]
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
