require "spec_helper"

RSpec.describe ActiveRecordExplainInEnglish do
  it "adds explain_in_english to ActiveRecord::Relation" do
    expect(User.all).to respond_to(:explain_in_english)
  end

  describe "#explain_in_english" do
    it "describes a bare relation" do
      expect(User.all.explain_in_english).to eq("Find users")
    end

    it "describes a simple equality" do
      expect(User.where(active: true).explain_in_english)
        .to eq("Find users, where active is true")
    end

    it "describes inequality" do
      expect(User.where.not(active: true).explain_in_english)
        .to eq("Find users, where active is not true")
    end

    it "describes a nil match as 'nothing'" do
      expect(User.where(name: nil).explain_in_english)
        .to eq("Find users, where name is nothing")
    end

    it "describes a range as a between" do
      expect(User.where(age: 18..65).explain_in_english)
        .to eq("Find users, where age is between 18 and 65")
    end

    it "describes an array match as 'one of'" do
      expect(User.where(role: %w[admin user]).explain_in_english)
        .to eq("Find users, where role is one of admin, user")
    end

    it "describes string values" do
      expect(User.where(name: "Jonny").explain_in_english)
        .to eq("Find users, where name is Jonny")
    end

    it "describes ascending order" do
      expect(User.order(:created_at).explain_in_english)
        .to eq("Find users, ordered by created at ascending")
    end

    it "describes descending order" do
      expect(User.order(created_at: :desc).explain_in_english)
        .to eq("Find users, ordered by created at descending")
    end

    it "describes limit and offset" do
      expect(User.offset(20).limit(10).explain_in_english)
        .to eq("Find users, limited to 10, offset by 20")
    end

    it "humanizes underscored column names" do
      expect(User.order(updated_at: :asc).explain_in_english)
        .to eq("Find users, ordered by updated at ascending")
    end

    it "joins multiple wheres with commas" do
      expect(User.where(active: true, role: "admin").explain_in_english)
        .to eq("Find users, where active is true, role is admin")
    end

    it "combines where, order, limit, and offset" do
      expect(
        User.where(active: true)
            .order(created_at: :desc)
            .limit(10)
            .offset(5)
            .explain_in_english
      ).to eq("Find users, where active is true, ordered by created at descending, limited to 10, offset by 5")
    end

    it "Can handle complex queries" do
      expect(
        User.where(active: true, age: 18..65, name: "John")
            .order(created_at: :desc)
            .limit(10)
            .offset(5)
            .explain_in_english
      ).to eq("Find users, where active is true, age is between 18 and 65, name is John, ordered by created at descending, limited to 10, offset by 5")
    end

    it "describes multiple ordering columns" do
      expect(User.order(active: :desc, created_at: :asc).explain_in_english)
        .to eq("Find users, ordered by active descending, created at ascending")
    end

    it "describes chained where calls as separate conditions" do
      expect(User.where(active: true).where(role: "admin").explain_in_english)
        .to eq("Find users, where active is true, role is admin")
    end

    it "describes an OR between two conditions" do
      relation = User.where(role: "admin").or(User.where(role: "user"))
      expect(relation.explain_in_english)
        .to eq("Find users, where role is admin or role is user")
    end

    it "describes a not-in array match" do
      expect(User.where.not(role: %w[admin user]).explain_in_english)
        .to eq("Find users, where role is none of admin, user")
    end

    it "describes selected columns" do
      expect(User.select(:name, :role).explain_in_english)
        .to eq("Find name, role from users")
    end

    it "describes distinct relations" do
      expect(User.distinct.explain_in_english)
        .to eq("Find distinct users")
    end

    it "describes distinct selected columns" do
      expect(User.select(:role).distinct.explain_in_english)
        .to eq("Find distinct role from users")
    end

    it "describes inner joins" do
      expect(User.joins(:posts).explain_in_english)
        .to eq("Find users, joined to posts")
    end

    it "describes left outer joins" do
      expect(User.left_joins(:posts).explain_in_english)
        .to eq("Find users, left joined to posts")
    end

    it "describes grouped relations" do
      expect(User.group(:role).explain_in_english)
        .to eq("Find users, grouped by role")
    end

    it "describes having clauses" do
      expect(User.group(:role).having("COUNT(*) > ?", 1).explain_in_english)
        .to eq("Find users, grouped by role, having COUNT(*) > 1")
    end

    it "describes raw SQL where clauses" do
      expect(User.where("age > ?", 18).explain_in_english)
        .to eq("Find users, where age > 18")
    end

    it "describes raw SQL order clauses" do
      expect(User.order("created_at DESC").explain_in_english)
        .to eq("Find users, ordered by created_at DESC")
    end

    it "describes raw SQL projections" do
      expect(User.select("COUNT(*) AS total").explain_in_english)
        .to eq("Find COUNT(*) AS total from users")
    end

    it "describes aggregate projections" do
      expect(User.select(User.arel_table[:id].count).explain_in_english)
        .to eq("Find count of id from users")
    end

    it "describes named function projections" do
      function = Arel::Nodes::NamedFunction.new("LOWER", [User.arel_table[:name]])

      expect(User.select(function).explain_in_english)
        .to eq("Find lower of name from users")
    end

    it "describes aliased projections" do
      expect(User.select(User.arel_table[:age].average.as("average_age")).explain_in_english)
        .to eq("Find average of age as average_age from users")
    end
  end
end
