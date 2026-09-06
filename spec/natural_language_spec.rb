require 'spec_helper'

RSpec.describe 'Natural explanations' do
  it 'describes users and combines familiar attributes into a sentence' do
    expect(User.all.explain_in_english).to eq('Find users.')
    expect(User.where(active: true).explain_in_english).to eq('Find active users.')
    expect(User.where(name: 'Jonny').explain_in_english).to eq('Find users named Jonny.')
    expect(User.where(age: 18..65).explain_in_english).to eq('Find users aged 18 to 65, inclusive.')

    relation = User.where(active: true, age: 18..65, name: 'John').order(created_at: :desc).limit(10).offset(5)
    expect(relation.explain_in_english)
      .to eq('Find active users named John, aged 18 to 65, inclusive. Order them newest first, skip the first 5, and return up to 10.')
  end

  it 'distinguishes false, missing values and empty strings' do
    expect(User.where(active: false).explain_in_english).to eq('Find users whose active flag is false.')
    expect(User.where.not(active: true).explain_in_english)
      .to eq('Find users whose active flag is not true (excluding missing values).')
    expect(User.where(name: nil).explain_in_english).to eq('Find users with no name recorded.')
    expect(User.where.not(name: nil).explain_in_english).to eq('Find users with a name recorded.')
    expect(User.where(name: '').explain_in_english).to eq('Find users whose name is an empty string.')
  end

  it 'uses conjunctions and quotes values that could be mistaken for query logic' do
    expect(User.where(role: ['admin', 'user']).explain_in_english)
      .to eq('Find users whose role is either "admin" or "user".')
    expect(User.where.not(role: ['admin', 'user']).explain_in_english)
      .to eq('Find users whose role is neither "admin" nor "user" (excluding missing values).')
    expect(User.where(active: true).where(role: 'admin').explain_in_english)
      .to eq('Find active users whose role is "admin".')
    expect(User.where(name: 'John or Jane').explain_in_english)
      .to eq('Find users named "John or Jane".')
  end

  it 'preserves AND and OR grouping instead of lifting conditions out of alternatives' do
    relation = User.where(active: true).where(User.arel_table[:role].eq('admin').or(User.arel_table[:age].gteq(18)))
    expect(relation.explain_in_english)
      .to eq('Find active users where (role is "admin" or age is at least 18).')

    relation = User.where(active: true, role: 'admin').or(User.where(active: false, role: 'user'))
    expect(relation.explain_in_english)
      .to eq('Find users where ((active flag is true and role is "admin") or (active flag is false and role is "user")).')
  end

  it 'expresses inclusive, exclusive and open-ended ranges accurately' do
    expect(User.where(age: 18...).explain_in_english).to eq('Find users aged 18 or over.')
    expect(User.where(age: ...65).explain_in_english).to eq('Find users aged under 65.')
    expect(User.where(age: ..65).explain_in_english).to eq('Find users aged 65 or under.')
    expect(User.where(age: 18...65).explain_in_english)
      .to eq('Find users aged 18 or over and aged under 65.')
  end

  it 'uses date comparisons and preserves the time and timezone' do
    timestamp = Time.utc(2026, 1, 2, 9, 30)
    expect(User.where(User.arel_table[:created_at].gteq(timestamp)).explain_in_english)
      .to eq('Find users whose creation time is on or after 2 January 2026 at 09:30:00 UTC.')
  end

  it 'uses the column type for ordering and retains secondary sort priority' do
    expect(User.order(created_at: :desc).limit(10).explain_in_english)
      .to eq('Find up to 10 users, newest first.')
    expect(User.order(updated_at: :asc).explain_in_english)
      .to eq('Find users. Order them by update time, earliest first.')
    expect(User.order(age: :desc, name: :asc).explain_in_english)
      .to eq('Find users. Order them by age, highest to lowest, then by name, in ascending text order.')
    expect(User.offset(20).limit(10).explain_in_english)
      .to eq('Find users. Skip the first 20 and return up to 10.')
    expect(User.limit(1).explain_in_english).to eq('Find up to 1 user.')
  end

  it 'distinguishes distinct values from distinct records and selected columns' do
    expect(User.select(:role).distinct.explain_in_english)
      .to eq('Find the unique roles used by users.')
    expect(User.distinct.explain_in_english).to eq('Find users, returning each user only once.')
    expect(User.select(:name, :role).explain_in_english).to eq('Find name and role from users.')
  end

  it 'explains simple association joins and their multiplicity' do
    relation = User.joins(:posts).where(posts: { published: true })
    expect(relation.explain_in_english)
      .to eq('Find users with published posts. A user appears once for each matching post.')
    expect(relation.distinct.explain_in_english)
      .to eq('Find users with published posts, returning each user only once.')
  end

  it 'retains join conditions and table ownership for complex joins' do
    relation = Comment.joins(:user, :post).where(users: { name: 'John' }, posts: { published: true })
    explanation = relation.explain_in_english
    expect(explanation).to eq('Find comments where users.name is "John" and posts.published flag is true. Join users on users.id is equal to comments.user id. Join posts on posts.id is equal to comments.post id. A comment may appear more than once when there are multiple matching combinations.')
  end

  it 'keeps left joins optional without claiming that later filters preserve every user' do
    relation = User.left_joins(:posts).where(posts: { published: true })
    expect(relation.explain_in_english)
      .to eq('Find users where posts.published flag is true. Include matching posts when available, joining on posts.user id is equal to users.id. A user may appear more than once when there are multiple matching combinations.')
  end

  it 'explains structured aggregates, aliases, grouping and HAVING' do
    relation = User.select(User.arel_table[:age].average.as('average_age')).group(:role)
    expect(relation.explain_in_english)
      .to eq('Find the average age (labelled average_age) from users. Group by role.')
    relation = User.select(User.arel_table[:id].count).group(:role).having(User.arel_table[:id].count.gt(2))
    expect(relation.explain_in_english)
      .to eq('Find the number of recorded id values from users. Group by role. Keep groups where the number of recorded id values is more than 2.')
  end

  it 'labels raw SQL rather than guessing its meaning' do
    expect(User.where('age > ?', 18).order('created_at DESC').explain_in_english)
      .to eq('Find users where SQL condition (age > 18) holds. Order them using SQL (created_at DESC).')
    expect(User.select('COUNT(*) AS total').explain_in_english)
      .to eq('Find SQL expression (COUNT(*) AS total) from users.')
  end

  it 'does not execute or load the relation being explained' do
    relation = User.where(active: true)
    expect(relation).not_to receive(:exec_queries)
    expect(relation.explain_in_english).to eq('Find active users.')
    expect(relation.loaded?).to be_falsey
  end

  it 'keeps compound negation intact' do
    expect(User.where.not(active: true, role: 'admin').explain_in_english)
      .to eq('Find users where not ((active flag is true and role is "admin")).')
  end

  it 'describes empty inclusion and exclusion lists without implying a match' do
    expect(User.where(id: []).explain_in_english)
      .to eq('Find users whose id matches an empty list (no records match).')
    expect(User.where.not(id: []).explain_in_english)
      .to eq('Find users whose id is unrestricted by the empty exclusion list.')
    expect(User.none.explain_in_english).to eq('Find users where SQL condition (1=0) holds.')
  end

  it 'lets Active Record quote raw SQL binds, including apostrophes, lists and named binds' do
    expect(User.where('name = ?', "O'Brien").explain_in_english)
      .to eq("Find users where SQL condition (name = 'O''Brien') holds.")
    expect(User.where('role IN (?)', ['admin', 'user']).explain_in_english)
      .to eq("Find users where SQL condition (role IN ('admin', 'user')) holds.")
    expect(User.where('name = :name OR role = :role', name: 'John', role: 'admin').explain_in_english)
      .to eq("Find users where SQL condition (name = 'John' OR role = 'admin') holds.")
    expect(User.where('name IS NULL').explain_in_english)
      .to eq('Find users where SQL condition (name IS NULL) holds.')
  end

  it 'attaches names to users rather than their joined posts' do
    expect(User.joins(:posts).where(name: 'John', posts: { published: true }).explain_in_english)
      .to eq('Find users named John with published posts. A user appears once for each matching post.')
  end

  it 'counts distinct non-null values and keeps aggregate aliases' do
    expect(User.select(User.arel_table[:role].count(true)).explain_in_english)
      .to eq('Find the number of distinct recorded role values from users.')
    expect(User.select(Arel.star.count.as('total')).explain_in_english)
      .to eq('Find the number of rows (labelled total) from users.')
  end

  it 'keeps its English conjunctions when the application uses another locale' do
    original_locales = I18n.available_locales
    I18n.available_locales = original_locales + [:fr]
    I18n.backend.store_translations(:fr, support: { array: { words_connector: ', ', two_words_connector: ' et ', last_word_connector: ' et ' } })
    I18n.with_locale(:fr) do
      expect(User.offset(20).limit(10).explain_in_english)
        .to eq('Find users. Skip the first 20 and return up to 10.')
    end
  ensure
    I18n.available_locales = original_locales
  end

  it 'matches the duplicate and distinct behaviour of an executed association query' do
    user = User.create!(name: 'John')
    Post.create!(user: user, published: true)
    Post.create!(user: user, published: true)
    relation = User.joins(:posts).where(posts: { published: true })
    expect(relation.pluck(:id)).to eq([user.id, user.id])
    expect(relation.explain_in_english)
      .to eq('Find users with published posts. A user appears once for each matching post.')
    expect(relation.distinct.pluck(:id)).to eq([user.id])
    expect(relation.distinct.explain_in_english)
      .to eq('Find users with published posts, returning each user only once.')
  end
end
