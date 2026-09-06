# ActiveRecordExplainInEnglish

[![Gem Version](https://badge.fury.io/rb/active_record_explain_in_english.svg)](https://rubygems.org/gems/active_record_explain_in_english)

ActiveRecordExplainInEnglish adds `explain_in_english` to `ActiveRecord::Relation`.

It describes the shape of an ActiveRecord query in plain English by walking the Arel nodes behind the relation. This is useful when you want to show, log, or teach what a query is asking for without showing raw SQL.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "active_record_explain_in_english", "~> 0.1.0"
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
# => "Find users."

User.where(active: true).explain_in_english
# => "Find active users."

User.where(age: 18..65)
    .order(created_at: :desc)
    .limit(10)
    .offset(5)
    .explain_in_english
# => "Find users aged 18 to 65, inclusive. Order them newest first, skip the first 5, and return up to 10."
```

It also handles common relation clauses:

```ruby
User.joins(:posts).where(posts: { published: true }).explain_in_english
# => "Find users with published posts. A user appears once for each matching post."
```

## Conversational explanations

Conversational wording is the default; call `explain_in_english` without any options.

```ruby
User.where(active: true, age: 18..65, name: 'John')
    .order(created_at: :desc)
    .limit(10)
    .offset(5)
    .explain_in_english
# => "Find active users named John, aged 18 to 65, inclusive. Order them newest first, skip the first 5, and return up to 10."

User.order(created_at: :desc).limit(10).explain_in_english
# => "Find up to 10 users, newest first."

User.where(name: nil).explain_in_english
# => "Find users with no name recorded."

User.select(:role).distinct.explain_in_english
# => "Find the unique roles used by users."

User.joins(:posts).where(posts: { published: true }).distinct.explain_in_english
# => "Find users with published posts, returning each user only once."

User.select(User.arel_table[:age].average.as('average_age')).explain_in_english
# => "Find the average age (labelled average_age) from users."
```

The translator composes sentences from the query structure using deterministic Ruby rules. It does not use an AI service or execute the relation to fetch records. Active Record may access schema metadata while constructing and describing the query.

- Familiar boolean attributes (`active`, `published`, `approved`, `archived`, `enabled`, `verified`) become adjectives when true. Other attributes use explicit field descriptions.
- Names, ages, dates and numeric ordering have contextual wording. Text ordering stays explicit because database collation determines its meaning.
- AND, OR and compound NOT retain their logical grouping. Missing values remain distinct from empty strings and false flags.
- Simple, direct, unscoped association joins get phrases such as “with published posts”. Complex, scoped and left joins keep their join conditions and table names explicit. Duplicate records are described where relevant.
- Structured Arel aggregates are described in English. Arbitrary SQL is labelled and retained, with bind values quoted by Active Record:

```ruby
User.where('age > ?', 18).explain_in_english
# => "Find users where SQL condition (age > 18) holds."
```

Unsupported Arel node types raise `NotImplementedError`; the translator does not silently omit them. It describes the query, including queries the database might reject; it does not validate SQL or predict a query plan.

This wording change is currently unreleased. It changes returned strings and punctuation from 0.1.0, so update any snapshots or assertions that depend on the old text when upgrading. The method name and zero-argument API are unchanged.

## Supported Query Shapes

Supported clauses include:

- bare relations
- `where` equality, inequality, ranges, arrays, `not`, `or`, and raw SQL fragments
- `order`, including hash/symbol orders and raw SQL order strings
- `limit` and `offset`
- `select`, `distinct`, aliases, aggregate functions, and named functions
- `joins` and `left_joins`
- `group` and `having`

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
