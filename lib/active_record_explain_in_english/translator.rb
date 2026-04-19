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
      when Arel::Nodes::Limit
        visit_limit(node)
      when Arel::Nodes::Offset
        visit_offset(node)
      when Arel::Nodes::Grouping
        visit(node.expr)
      else
        raise NotImplementedError, "ActiveRecordExplainInEnglish cannot translate #{node.class}"
      end
    end

    def visit_select_statement(node)
      core = node.cores.first
      parts = ["Find #{visit(core)}"]

      if core.wheres.any?
        conditions = core.wheres.map { |where| visit(where) }.join(", ")
        parts << "where #{conditions}"
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

    def visit_limit(node)
      "limited to #{value_for(node.expr)}"
    end

    def visit_offset(node)
      "offset by #{value_for(node.expr)}"
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
  end
end
