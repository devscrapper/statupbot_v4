module Visits
  module Advertisings
    class NoAdvertising < Advertising

      def advert (&block)
        nil
      end
      def to_s
        "\n"
      end
    end
  end
end