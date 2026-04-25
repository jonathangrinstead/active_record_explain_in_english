module ActiveRecordExplainInEnglish
  class Translator
    def initialize(relation)
      @relation = relation
    end

    def translate
      visit(@relation.arel.ast)
    end

    private

    def visit(node)
      case node
      when Arel::Nodes::SelectStatement
        visit_select_statement(node)
      when Arel::Nodes::SelectCore
        visit_select_core(node)
      when Arel::Table
        visit_table(node)
      when Arel::Attributes::Attribute
        visit_attribute(node)
      when Arel::Nodes::InnerJoin
        visit_inner_join(node)
      when Arel::Nodes::OuterJoin
        visit_outer_join(node)
      when Arel::Nodes::Equality
        visit_equality(node)
      when Arel::Nodes::NotEqual
        visit_not_equal(node)
      when Arel::Nodes::GreaterThan
        visit_greater_than(node)
      when Arel::Nodes::GreaterThanOrEqual
        visit_greater_than_or_equal(node)
      when Arel::Nodes::LessThan
        visit_less_than(node)
      when Arel::Nodes::LessThanOrEqual
        visit_less_than_or_equal(node)
      when Arel::Nodes::Between
        visit_between(node)
      when Arel::Nodes::And
        visit_and(node)
      when Arel::Nodes::Or
        visit_or(node)
      when Arel::Nodes::HomogeneousIn
        visit_homogeneous_in(node)
      when Arel::Nodes::In
        visit_in(node)
      when Arel::Nodes::NotIn
        visit_not_in(node)
      when Arel::Nodes::Ascending
        visit_ascending(node)
      when Arel::Nodes::Descending
        visit_descending(node)
      when Arel::Nodes::Group
        visit_group(node)
      when Arel::Nodes::Limit
        visit_limit(node)
      when Arel::Nodes::Offset
        visit_offset(node)
      when Arel::Nodes::SqlLiteral, String
        visit_sql_literal(node)
      when Arel::Nodes::BoundSqlLiteral
        visit_bound_sql_literal(node)
      when Arel::Nodes::As
        visit_as(node)
      when Arel::Nodes::NamedFunction
        visit_function(node, node.name.downcase)
      when Arel::Nodes::Count
        visit_function(node, "count")
      when Arel::Nodes::Avg
        visit_function(node, "average")
      when Arel::Nodes::Sum
        visit_function(node, "sum")
      when Arel::Nodes::Min
        visit_function(node, "minimum")
      when Arel::Nodes::Max
        visit_function(node, "maximum")
      when Arel::Nodes::Grouping
        visit(node.expr)
      else
        raise NotImplementedError, "ActiveRecordExplainInEnglish cannot translate #{node.class}"
      end
    end

    def visit_select_statement(node)
      core = node.cores.first
      parts = ["Find #{select_description(core)}"]

      if core.source.right.any?
        parts << core.source.right.map { |join| visit(join) }.join(", ")
      end

      if core.wheres.any?
        conditions = core.wheres.map { |where| visit(where) }.join(", ")
        parts << "where #{conditions}"
      end

      if core.groups.any?
        parts << "grouped by #{core.groups.map { |group| visit(group) }.join(", ")}"
      end

      if core.havings.any?
        parts << "having #{core.havings.map { |having| visit(having) }.join(", ")}"
      end

      if node.orders.any?
        parts << "ordered by #{node.orders.map { |order| visit(order) }.join(", ")}"
      end

      parts << visit(node.limit) if node.limit
      parts << visit(node.offset) if node.offset

      parts.join(", ")
    end

    def visit_select_core(node)
      visit(node.source.left)
    end

    def visit_table(node)
      node.name
    end

    def visit_attribute(node)
      node.name.to_s.tr("_", " ")
    end

    def visit_inner_join(node)
      "joined to #{visit(node.left)}"
    end

    def visit_outer_join(node)
      "left joined to #{visit(node.left)}"
    end

    def visit_equality(node)
      raw = raw_value(node.right)
      raw.nil? ? "#{visit(node.left)} is nothing" : "#{visit(node.left)} is #{format_value(raw)}"
    end

    def visit_not_equal(node)
      raw = raw_value(node.right)
      raw.nil? ? "#{visit(node.left)} is anything" : "#{visit(node.left)} is not #{format_value(raw)}"
    end

    def visit_greater_than(node)
      "#{visit(node.left)} is greater than #{value_for(node.right)}"
    end

    def visit_greater_than_or_equal(node)
      "#{visit(node.left)} is greater than or equal to #{value_for(node.right)}"
    end

    def visit_less_than(node)
      "#{visit(node.left)} is less than #{value_for(node.right)}"
    end

    def visit_less_than_or_equal(node)
      "#{visit(node.left)} is less than or equal to #{value_for(node.right)}"
    end

    def visit_between(node)
      lower, upper = node.right.children
      "#{visit(node.left)} is between #{value_for(lower)} and #{value_for(upper)}"
    end

    def visit_and(node)
      node.children.map { |child| visit(child) }.join(", ")
    end

    def visit_or(node)
      "#{visit(node.left)} or #{visit(node.right)}"
    end

    def visit_homogeneous_in(node)
      verb = node.type == :in ? "is one of" : "is none of"
      "#{visit(node.attribute)} #{verb} #{format_value(node.values)}"
    end

    def visit_in(node)
      list = Array(node.right).map { |value| value_for(value) }.join(", ")
      "#{visit(node.left)} is one of #{list}"
    end

    def visit_not_in(node)
      list = Array(node.right).map { |value| value_for(value) }.join(", ")
      "#{visit(node.left)} is none of #{list}"
    end

    def visit_ascending(node)
      "#{visit(node.expr)} ascending"
    end

    def visit_descending(node)
      "#{visit(node.expr)} descending"
    end

    def visit_group(node)
      visit(node.expr)
    end

    def visit_limit(node)
      "limited to #{value_for(node.expr)}"
    end

    def visit_offset(node)
      "offset by #{value_for(node.expr)}"
    end

    def visit_sql_literal(node)
      node.to_s
    end

    def visit_bound_sql_literal(node)
      sql = node.sql_with_placeholders.dup

      Array(node.positional_binds).each do |bind|
        sql = sql.sub("?", format_value(raw_value(bind)))
      end

      Array(node.named_binds).each do |name, bind|
        sql = sql.gsub(":#{name}", format_value(raw_value(bind)))
      end

      strip_wrapping_parentheses(sql)
    end

    def visit_as(node)
      "#{visit(node.left)} as #{visit(node.right)}"
    end

    def visit_function(node, name)
      expressions = node.expressions.map { |expression| visit(expression) }.join(", ")
      "#{name} of #{expressions}"
    end

    def value_for(node)
      format_value(raw_value(node))
    end

    def raw_value(node)
      case node
      when Arel::Nodes::Casted, Arel::Nodes::Quoted
        node.value
      when Arel::Nodes::BindParam
        raw_value(node.value)
      when ActiveModel::Attribute
        node.value_before_type_cast
      else
        node
      end
    end

    def format_value(value)
      case value
      when nil
        "nothing"
      when true, false
        value.to_s
      when String
        value
      when Numeric
        value.to_s
      when Array
        value.map { |element| format_value(element) }.join(", ")
      else
        value.inspect
      end
    end

    def select_description(core)
      table = visit(core)
      target = default_projection?(core) ? table : "#{core.projections.map { |projection| visit(projection) }.join(", ")} from #{table}"

      core.set_quantifier.is_a?(Arel::Nodes::Distinct) ? "distinct #{target}" : target
    end

    def default_projection?(core)
      core.projections.one? &&
        core.projections.first.is_a?(Arel::Attributes::Attribute) &&
        core.projections.first.name == "*"
    end

    def strip_wrapping_parentheses(sql)
      sql = sql.strip
      wrapping_parentheses?(sql) ? sql[1...-1] : sql
    end

    def wrapping_parentheses?(sql)
      if sql.start_with?("(") && sql.end_with?(")")
        depth = 0
        closes_before_end = sql.chars.each_with_index.any? do |character, index|
          depth += 1 if character == "("
          depth -= 1 if character == ")"

          depth.zero? && index < sql.length - 1
        end

        depth.zero? && !closes_before_end
      else
        false
      end
    end
  end
end
