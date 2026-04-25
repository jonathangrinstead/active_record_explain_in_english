# ActiveRecordExplainInEnglish

ActiveRecordExplainInEnglish adds `explain_in_english` to `ActiveRecord::Relation`.

It describes the shape of an ActiveRecord query in plain English by walking the Arel nodes behind the relation. This is useful when you want to show, log, or teach what a query is asking for without showing raw SQL.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "active_record_explain_in_english"
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install active_record_explain_in_english
```

## Usage

Call `explain_in_english` on any ActiveRecord relation:

```ruby
User.all.explain_in_english
# => "Find users"

User.where(active: true).explain_in_english
# => "Find users, where active is true"

User.where(age: 18..65)
    .order(created_at: :desc)
    .limit(10)
    .offset(5)
    .explain_in_english
# => "Find users, where age is between 18 and 65, ordered by created at descending, limited to 10, offset by 5"
```

It also handles common relation clauses:

```ruby
User.select(:name, :role).explain_in_english
# => "Find name, role from users"

User.select(:role).distinct.explain_in_english
# => "Find distinct role from users"

User.joins(:posts).where(posts: { published: true }).explain_in_english
# => "Find users, joined to posts, where published is true"

User.group(:role).having("COUNT(*) > ?", 1).explain_in_english
# => "Find users, grouped by role, having COUNT(*) > 1"
```

## Supported Query Shapes

The first release supports:

- bare relations
- `where` equality, inequality, ranges, arrays, `not`, `or`, and raw SQL fragments
- `order`, including hash/symbol orders and raw SQL order strings
- `limit` and `offset`
- `select`, `distinct`, aliases, aggregate functions, and named functions
- `joins` and `left_joins`
- `group` and `having`

Unsupported Arel nodes raise `NotImplementedError` so missing coverage is visible.

## Development

After checking out the repo, run:

```bash
bin/setup
bundle exec rspec
```

You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jonathangrinstead/active_record_explain_in_english.

## License

The gem is available as open source under the terms of the MIT License.
