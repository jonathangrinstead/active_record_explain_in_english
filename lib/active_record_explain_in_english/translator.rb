module ActiveRecordExplainInEnglish
  class Translator
    ADJECTIVES = ['active', 'published', 'approved', 'archived', 'enabled', 'verified'].freeze
    COMPARISONS = {
      Arel::Nodes::GreaterThan => ['more than', 'over', 'after'],
      Arel::Nodes::GreaterThanOrEqual => ['at least', nil, 'on or after'],
      Arel::Nodes::LessThan => ['less than', 'under', 'before'],
      Arel::Nodes::LessThanOrEqual => ['at most', nil, 'on or before']
    }.freeze

    def initialize(relation)
      @relation = relation
    end

    def translate
      self.visit(@relation.arel.ast)
    end

    private

    def visit(node)
      case node
      when Arel::Nodes::Not
        "not (#{self.predicate(node.expr)})"
      when Arel::Nodes::TableAlias
        "#{self.visit(node.left)} (as #{node.right})"
      when Arel::Nodes::True
        'the condition always holds'
      when Arel::Nodes::False
        'the condition never holds'
      when Arel::Nodes::SelectStatement
        self.visit_select_statement(node)
      when Arel::Nodes::SelectCore
        self.visit_select_core(node)
      when Arel::Table
        self.visit_table(node)
      when Arel::Attributes::Attribute
        self.visit_attribute(node)
      when Arel::Nodes::InnerJoin, Arel::Nodes::OuterJoin
        self.join_description(node)
      when Arel::Nodes::Equality
        self.visit_equality(node)
      when Arel::Nodes::NotEqual
        self.visit_not_equal(node)
      when Arel::Nodes::GreaterThan, Arel::Nodes::GreaterThanOrEqual, Arel::Nodes::LessThan, Arel::Nodes::LessThanOrEqual
        self.comparison(node)
      when Arel::Nodes::Between
        self.visit_between(node)
      when Arel::Nodes::And
        self.visit_and(node)
      when Arel::Nodes::Or
        self.visit_or(node)
      when Arel::Nodes::HomogeneousIn
        self.visit_homogeneous_in(node)
      when Arel::Nodes::In
        self.visit_in(node)
      when Arel::Nodes::NotIn
        self.visit_not_in(node)
      when Arel::Nodes::Ascending, Arel::Nodes::Descending
        self.order_description(node)
      when Arel::Nodes::Group
        self.visit_group(node)
      when Arel::Nodes::Limit
        self.visit_limit(node)
      when Arel::Nodes::Offset
        self.visit_offset(node)
      when Arel::Nodes::SqlLiteral, String
        self.visit_sql_literal(node)
      when Arel::Nodes::BoundSqlLiteral
        self.visit_bound_sql_literal(node)
      when Arel::Nodes::As
        self.visit_as(node)
      when Arel::Nodes::NamedFunction
        self.visit_function(node, node.name.downcase)
      when Arel::Nodes::Count
        self.visit_function(node, "count")
      when Arel::Nodes::Avg
        self.visit_function(node, "average")
      when Arel::Nodes::Sum
        self.visit_function(node, "sum")
      when Arel::Nodes::Min
        self.visit_function(node, "minimum")
      when Arel::Nodes::Max
        self.visit_function(node, "maximum")
      when Arel::Nodes::Grouping
        self.visit(node.expr)
      else
        raise NotImplementedError, "ActiveRecordExplainInEnglish cannot translate #{node.class}"
      end
    end

    def visit_select_statement(node)
      previous_table, previous_joined = @base_table, @joined
      core = node.cores.first
      @joined = core.source.right.any?
      @base_table = core.source.left
      conditions = core.wheres.flat_map { |condition| self.conjunctions(condition) }
      records = self.default_projection?(core)
      distinct = core.set_quantifier.is_a?(Arel::Nodes::Distinct)
      table = self.visit(core.source.left)
      table = "rows from SQL source (#{core.source.left})" if core.source.left.is_a?(Arel::Nodes::SqlLiteral)
      adjectives, remaining = conditions.partition { |condition| records && self.adjective?(condition, @base_table) }
      subject = [*adjectives.collect { |condition| condition.left.name.to_s }, table].join(' ')
      details = []
      join = self.simple_association(core)

      if join
        matching, remaining = remaining.partition { |condition| self.adjective?(condition, core.source.right.first.left) }
        association = " with #{[*matching.collect { |condition| condition.left.name.to_s }, join.name.to_s.tr('_', ' ')].join(' ')}"
      end

      sentence = records ? "Find #{subject}" : "Find #{self.projection_description(core)} from #{table}"
      if records
        names, remaining = remaining.partition { |condition| self.named?(condition) }
        sentence += " named #{names.collect { |condition| self.person_name(self.raw_value(condition.right)) }.join(' and named ')}" if names.any?
        ages, remaining = remaining.partition { |condition| self.age_condition?(condition) }
        if ages.any?
          sentence += names.any? ? ', ' : ' '
          sentence += ages.collect { |condition| self.age_description(condition) }.join(' and ')
        end
      end

      sentence += association if association

      if remaining.any?
        if records && !@joined && remaining.one? && remaining.first.is_a?(Arel::Nodes::Equality) && self.raw_value(remaining.first.right).nil?
          sentence += " with no #{self.visit(remaining.first.left)} recorded"
        elsif records && !@joined && remaining.one? && remaining.first.is_a?(Arel::Nodes::NotEqual) && self.raw_value(remaining.first.right).nil?
          sentence += " with a #{self.visit(remaining.first.left)} recorded"
        else
          relative = records && !@joined && remaining.all? { |condition| self.attribute_condition?(condition) }
          sentence += " #{relative ? 'whose' : 'where'} #{remaining.collect { |condition| self.predicate(condition) }.join(' and ')}"
        end
      end

      if distinct
        if records
          sentence += ", returning each #{table.singularize} only once"
        elsif core.projections.one? && core.projections.first.is_a?(Arel::Attributes::Attribute) && core.groups.empty? && core.wheres.empty? && !@joined
          sentence = "Find the unique #{self.visit(core.projections.first).pluralize} used by #{table}"
        else
          sentence += ', returning each distinct result only once'
        end
      end

      core.source.right.each { |source| details << self.join_description(source) } unless join
      if @joined && records && core.groups.empty? && !distinct
        details << if join && join.collection?
          "A #{table.singularize} appears once for each matching #{join.name.to_s.singularize.tr('_', ' ')}"
        elsif !join
          "A #{table.singularize} may appear more than once when there are multiple matching combinations"
        end
      end
      details << "Group by #{core.groups.collect { |group| self.visit(group) }.to_sentence(locale: :en)}" if core.groups.any?
      details << "Keep groups where #{core.havings.collect { |having| self.predicate(having) }.join(' and ')}" if core.havings.any?

      compact = records && core.wheres.empty? && !@joined && !distinct && core.groups.empty? && core.havings.empty? && !node.offset
      if compact && node.limit
        count = self.value_for(node.limit.expr)
        noun = count == '1' ? table.singularize : table
        sentence = "Find up to #{count} #{noun}"
      end
      if compact && node.orders.one? && self.creation_order?(node.orders.first)
        sentence += ", #{self.order_description(node.orders.first)}"
      else
        actions = []
        actions << "order them #{node.orders.collect { |order| self.order_description(order) }.join(', then ')}" if node.orders.any?
        actions << "skip the first #{self.value_for(node.offset.expr)}" if node.offset
        actions << "return up to #{self.value_for(node.limit.expr)}" if node.limit && !compact
        details << actions.to_sentence(locale: :en).sub(/\A./) { |letter| letter.upcase } if actions.any?
      end
      [sentence, *details.compact].join('. ') + '.'
    ensure
      @base_table, @joined = previous_table, previous_joined
    end

    def conjunctions(node)
      if node.is_a?(Arel::Nodes::And)
        node.children.flat_map { |child| self.conjunctions(child) }
      elsif node.is_a?(Arel::Nodes::Grouping) && node.expr.is_a?(Arel::Nodes::And)
        self.conjunctions(node.expr)
      else
        [node]
      end
    end

    def attribute_condition?(node)
      attribute = node.is_a?(Arel::Nodes::HomogeneousIn) ? node.attribute : (node.left if node.respond_to?(:left))
      attribute.is_a?(Arel::Attributes::Attribute)
    end

    def base_attribute?(attribute)
      attribute.is_a?(Arel::Attributes::Attribute) && attribute.relation == @base_table
    end

    def adjective?(node, table)
      node.is_a?(Arel::Nodes::Equality) && node.left.is_a?(Arel::Attributes::Attribute) &&
        node.left.relation == table && ADJECTIVES.include?(node.left.name.to_s) &&
        self.column_type(node.left) == :boolean && self.raw_value(node.right) == true
    end

    def named?(node)
      node.is_a?(Arel::Nodes::Equality) && self.base_attribute?(node.left) &&
        node.left.name.to_s == 'name' && self.raw_value(node.right).is_a?(String) && !self.raw_value(node.right).empty?
    end

    def person_name(value)
      if value.match?(/\A[[:alpha:]][[:alpha:] '\-]*\z/) && !value.match?(/\b(and|or|not)\b/i)
        value
      else
        self.format_value(value)
      end
    end

    def age_condition?(node)
      (COMPARISONS.key?(node.class) || node.is_a?(Arel::Nodes::Between) || node.is_a?(Arel::Nodes::Equality)) &&
        self.base_attribute?(node.left) && node.left.name.to_s == 'age' &&
        (node.is_a?(Arel::Nodes::Between) || self.raw_value(node.right).is_a?(Numeric))
    end

    def age_description(node)
      case node
      when Arel::Nodes::Between
        lower, upper = node.right.children
        "aged #{self.value_for(lower)} to #{self.value_for(upper)}, inclusive"
      when Arel::Nodes::GreaterThanOrEqual
        "aged #{self.value_for(node.right)} or over"
      when Arel::Nodes::LessThanOrEqual
        "aged #{self.value_for(node.right)} or under"
      when Arel::Nodes::Equality
        "aged #{self.value_for(node.right)}"
      else
        "aged #{COMPARISONS.fetch(node.class)[1]} #{self.value_for(node.right)}"
      end
    end

    def simple_association(core)
      name = @relation.joins_values.first
      if core.source.left == @relation.klass.arel_table && self.default_projection?(core) && core.groups.empty? && core.source.right.one? &&
          core.source.right.first.is_a?(Arel::Nodes::InnerJoin) && @relation.joins_values.one? && name.is_a?(Symbol)
        reflection = @relation.klass.reflect_on_association(name)
        if reflection && !reflection.polymorphic? && !reflection.options[:through] && !reflection.scope &&
            core.source.right.first.left.is_a?(Arel::Table) && core.source.right.first.left.name == reflection.klass.table_name &&
            reflection.klass.default_scopes.empty? && reflection.klass.descends_from_active_record?
          reflection
        end
      end
    end

    def join_description(node)
      if node.is_a?(Arel::Nodes::InnerJoin) || node.is_a?(Arel::Nodes::OuterJoin)
        condition = self.predicate(node.right.expr)
        if node.is_a?(Arel::Nodes::OuterJoin)
          "Include matching #{self.visit(node.left)} when available, joining on #{condition}"
        else
          "Join #{self.visit(node.left)} on #{condition}"
        end
      else
        "Apply #{self.visit(node)}"
      end
    end

    def column_type(attribute)
      if attribute.is_a?(Arel::Attributes::Attribute)
        table = attribute.relation
        table = table.left if table.is_a?(Arel::Nodes::TableAlias)
        table.type_for_attribute(attribute.name.to_s).type if table.is_a?(Arel::Table) && table.able_to_type_cast?

      end
    end

    def visit_table(node)
      node.name.tr('_', ' ')
    end

    def visit_attribute(node)
      name = case node.name.to_s
      when 'created_at'
        'creation time'
      when 'updated_at'
        'update time'
      else
        node.name.to_s.tr('_', ' ')
      end
      name += ' flag' if self.column_type(node) == :boolean
      @joined ? "#{node.relation.name}.#{name}" : name
    end

    def visit_equality(node)
      value = self.raw_value(node.right)
      if node.right.is_a?(Arel::Attributes::Attribute)
        "#{self.visit(node.left)} is equal to #{self.visit(node.right)}"
      elsif value.nil?
        "#{self.visit(node.left)} is not recorded"
      else
        "#{self.visit(node.left)} is #{self.value_for(node.right)}"
      end
    end

    def visit_not_equal(node)
      if self.raw_value(node.right).nil?
        "#{self.visit(node.left)} is recorded"
      else
        "#{self.visit(node.left)} is not #{self.value_for(node.right)} (excluding missing values)"
      end
    end

    def comparison(node)
      wording = COMPARISONS.fetch(node.class)
      temporal = [:date, :datetime, :timestamp, :time].include?(self.column_type(node.left))
      "#{self.visit(node.left)} is #{wording[temporal ? 2 : 0]} #{self.value_for(node.right)}"
    end

    def visit_between(node)
      lower, upper = node.right.children
      "#{self.visit(node.left)} is between #{self.value_for(lower)} and #{self.value_for(upper)}, inclusive"
    end

    def visit_and(node)
      "(#{node.children.collect { |child| self.predicate(child) }.join(' and ')})"
    end

    def visit_or(node)
      "(#{self.predicate(node.left)} or #{self.predicate(node.right)})"
    end

    def visit_homogeneous_in(node)
      self.membership(node.attribute, node.values, node.type == :in)
    end

    def visit_in(node)
      self.membership(node.left, node.right, true)
    end

    def visit_not_in(node)
      self.membership(node.left, node.right, false)
    end

    def membership(attribute, values, positive)
      if values.is_a?(Array)
        list = values.collect { |value| self.value_for(value) }
        if list.empty?
          "#{self.visit(attribute)} #{positive ? 'matches an empty list (no records match)' : 'is unrestricted by the empty exclusion list'}"
        elsif list.one?
          "#{self.visit(attribute)} is #{positive ? '' : 'not '}#{list.first}#{positive ? '' : ' (excluding missing values)'}"
        else
          "#{self.visit(attribute)} is #{positive ? 'either' : 'neither'} #{list.to_sentence(locale: :en, last_word_connector: positive ? ', or ' : ', nor ', two_words_connector: positive ? ' or ' : ' nor ')}#{positive ? '' : ' (excluding missing values)'}"
        end
      else
        "#{self.visit(attribute)} is #{positive ? 'in' : 'not in'} the results of (#{self.visit(values)})"
      end
    end

    def creation_order?(node)
      (node.is_a?(Arel::Nodes::Ascending) || node.is_a?(Arel::Nodes::Descending)) &&
        self.base_attribute?(node.expr) && node.expr.name.to_s == 'created_at' && !@joined &&
        [:datetime, :timestamp].include?(self.column_type(node.expr))
    end

    def order_description(node)
      if node.is_a?(Arel::Nodes::Ascending) || node.is_a?(Arel::Nodes::Descending)
        descending = node.is_a?(Arel::Nodes::Descending)
        if self.creation_order?(node)
          descending ? 'newest first' : 'oldest first'
        else
          direction = case self.column_type(node.expr)
          when :integer, :float, :decimal
            descending ? 'highest to lowest' : 'lowest to highest'
          when :date, :datetime, :timestamp, :time
            descending ? 'latest first' : 'earliest first'
          when :string, :text
            descending ? 'in descending text order' : 'in ascending text order'
          else
            descending ? 'in descending order' : 'in ascending order'
          end
          "by #{self.visit(node.expr)}, #{direction}"
        end
      else
        "using SQL (#{node})"
      end
    end

    def projection_description(core)
      core.projections.collect { |projection| self.visit(projection) }.to_sentence(locale: :en)
    end

    def visit_sql_literal(node)
      "SQL expression (#{node})"
    end

    def visit_bound_sql_literal(node)
      "SQL expression (#{self.bound_sql(node)})"
    end

    def predicate(node)
      case node
      when Arel::Nodes::Grouping
        self.predicate(node.expr)
      when Arel::Nodes::BoundSqlLiteral
        "SQL condition (#{self.bound_sql(node)}) holds"
      when Arel::Nodes::SqlLiteral, String
        "SQL condition (#{node}) holds"
      else
        self.visit(node)
      end
    end

    def bound_sql(node)
      @relation.klass.connection_pool.with_connection do |connection|
        connection.unprepared_statement { self.strip_wrapping_parentheses(connection.to_sql(node)) }
      end
    end

    def visit_as(node)
      "#{self.visit(node.left)} (labelled #{node.right})"
    end

    def visit_function(node, name)
      expressions = node.expressions.collect { |expression| expression.to_s == '*' ? '*' : self.visit(expression) }.to_sentence(locale: :en)
      distinct = node.respond_to?(:distinct) && node.distinct ? 'distinct ' : ''
      description = case name
      when 'count'
        expressions == '*' ? 'the number of rows' : "the number of #{distinct}recorded #{expressions} values"
      when 'average', 'sum', 'minimum', 'maximum'
        "the #{name} #{distinct}#{expressions}"
      else
        "#{name} applied to #{expressions}"
      end
      node.respond_to?(:alias) && node.alias ? "#{description} (labelled #{node.alias})" : description
    end

    def raw_value(node)
      case node
      when Arel::Nodes::Casted, Arel::Nodes::Quoted, ActiveModel::Attribute
        node.value
      when Arel::Nodes::BindParam
        self.raw_value(node.value)
      else
        node
      end
    end

    def value_for(node)
      value = self.raw_value(node)
      if value.is_a?(Arel::Attributes::Attribute) || value.is_a?(Arel::Nodes::Node) || value.is_a?(Arel::Nodes::SqlLiteral)
        self.visit(value)
      else
        self.format_value(value)
      end
    end

    def visit_select_core(node)
      self.visit(node.source.left)
    end

    def visit_group(node)
      self.visit(node.expr)
    end

    def visit_limit(node)
      "limited to #{value_for(node.expr)}"
    end

    def visit_offset(node)
      "offset by #{value_for(node.expr)}"
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

    def format_value(value)
      case value
      when String
        value.empty? ? 'an empty string' : value.inspect
      when Time, DateTime, ActiveSupport::TimeWithZone
        precision = value.strftime('%N').sub(/0+\z/, '')
        fraction = precision.empty? ? '' : ".#{precision}"
        "#{value.strftime('%-d %B %Y at %H:%M:%S')}#{fraction} #{value.strftime('%z') == '+0000' ? 'UTC' : value.strftime('%:z')}"
      when Date
        value.strftime('%-d %B %Y')
      when nil
        'a missing value'
      when true, false, Numeric
        value.to_s
      when Array
        value.collect { |element| self.format_value(element) }.to_sentence(locale: :en)
      else
        value.inspect
      end
    end
  end
end
