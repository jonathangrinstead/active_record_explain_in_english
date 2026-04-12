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

      end
    end
  end
end
