require "spec_helper"

RSpec.describe ActiveRecordExplainInEnglish do
  it "adds explain_in_english to ActiveRecord::Relation" do
    expect(User.all).to respond_to(:explain_in_english)
  end

  describe "#explain_in_english" do
    it "describes a bare relation" do
      expect(User.all.explain_in_english).to eq('Find users.')
    end

    it "describes a simple equality" do
      expect(User.where(active: true).explain_in_english)
        .to eq('Find active users.')
    end

    it "describes inequality" do
      expect(User.where.not(active: true).explain_in_english)
        .to eq('Find users whose active flag is not true (excluding missing values).')
    end

    it "describes missing values" do
      expect(User.where(name: nil).explain_in_english)
        .to eq('Find users with no name recorded.')
    end

    it "describes a range as a between" do
      expect(User.where(age: 18..65).explain_in_english)
        .to eq('Find users aged 18 to 65, inclusive.')
    end

    it "describes alternatives naturally" do
      expect(User.where(role: %w[admin user]).explain_in_english)
        .to eq('Find users whose role is either "admin" or "user".')
    end

    it "describes string values" do
      expect(User.where(name: "Jonny").explain_in_english)
        .to eq('Find users named Jonny.')
    end

    it "describes ascending order" do
      expect(User.order(:created_at).explain_in_english)
        .to eq('Find users, oldest first.')
    end

    it "describes descending order" do
      expect(User.order(created_at: :desc).explain_in_english)
        .to eq('Find users, newest first.')
    end

    it "describes limit and offset" do
      expect(User.offset(20).limit(10).explain_in_english)
        .to eq('Find users. Skip the first 20 and return up to 10.')
    end

    it "humanizes underscored column names" do
      expect(User.order(updated_at: :asc).explain_in_english)
        .to eq('Find users. Order them by update time, earliest first.')
    end

    it "combines multiple conditions naturally" do
      expect(User.where(active: true, role: "admin").explain_in_english)
        .to eq('Find active users whose role is "admin".')
    end

    it "combines where, order, limit, and offset" do
      expect(
        User.where(active: true)
            .order(created_at: :desc)
            .limit(10)
            .offset(5)
            .explain_in_english
      ).to eq('Find active users. Order them newest first, skip the first 5, and return up to 10.')
    end

    it "describes a complete query in two sentences" do
      expect(
        User.where(active: true, age: 18..65, name: "John")
            .order(created_at: :desc)
            .limit(10)
            .offset(5)
            .explain_in_english
      ).to eq('Find active users named John, aged 18 to 65, inclusive. Order them newest first, skip the first 5, and return up to 10.')
    end

    it "describes multiple ordering columns" do
      expect(User.order(active: :desc, created_at: :asc).explain_in_english)
        .to eq('Find users. Order them by active flag, in descending order, then oldest first.')
    end

    it "describes chained where calls as separate conditions" do
      expect(User.where(active: true).where(role: "admin").explain_in_english)
        .to eq('Find active users whose role is "admin".')
    end

    it "describes an OR between two conditions" do
      relation = User.where(role: "admin").or(User.where(role: "user"))
      expect(relation.explain_in_english)
        .to eq('Find users where (role is "admin" or role is "user").')
    end

    it "describes a not-in array match" do
      expect(User.where.not(role: %w[admin user]).explain_in_english)
        .to eq('Find users whose role is neither "admin" nor "user" (excluding missing values).')
    end

    it "describes selected columns" do
      expect(User.select(:name, :role).explain_in_english)
        .to eq('Find name and role from users.')
    end

    it "describes distinct relations" do
      expect(User.distinct.explain_in_english)
        .to eq('Find users, returning each user only once.')
    end

    it "describes distinct selected columns" do
      expect(User.select(:role).distinct.explain_in_english)
        .to eq('Find the unique roles used by users.')
    end

    it "describes inner joins" do
      expect(User.joins(:posts).explain_in_english)
        .to eq('Find users with posts. A user appears once for each matching post.')
    end

    it "describes left outer joins" do
      expect(User.left_joins(:posts).explain_in_english)
        .to eq('Find users. Include matching posts when available, joining on posts.user id is equal to users.id. A user may appear more than once when there are multiple matching combinations.')
    end

    it "describes grouped relations" do
      expect(User.group(:role).explain_in_english)
        .to eq('Find users. Group by role.')
    end

    it "describes having clauses" do
      expect(User.group(:role).having("COUNT(*) > ?", 1).explain_in_english)
        .to eq('Find users. Group by role. Keep groups where SQL condition (COUNT(*) > 1) holds.')
    end

    it "describes raw SQL where clauses" do
      expect(User.where("age > ?", 18).explain_in_english)
        .to eq('Find users where SQL condition (age > 18) holds.')
    end

    it "describes raw SQL order clauses" do
      expect(User.order("created_at DESC").explain_in_english)
        .to eq('Find users. Order them using SQL (created_at DESC).')
    end

    it "describes raw SQL projections" do
      expect(User.select("COUNT(*) AS total").explain_in_english)
        .to eq('Find SQL expression (COUNT(*) AS total) from users.')
    end

    it "describes aggregate projections" do
      expect(User.select(User.arel_table[:id].count).explain_in_english)
        .to eq('Find the number of recorded id values from users.')
    end

    it "describes named function projections" do
      function = Arel::Nodes::NamedFunction.new("LOWER", [User.arel_table[:name]])

      expect(User.select(function).explain_in_english)
        .to eq('Find lower applied to name from users.')
    end

    it "describes aliased projections" do
      expect(User.select(User.arel_table[:age].average.as("average_age")).explain_in_english)
        .to eq('Find the average age (labelled average_age) from users.')
    end
  end
end
