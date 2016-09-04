module Visits
  module Advertisings
    class NoAdvertising < Advertising

      def advert (&block)
        nil
      end
    end
  end
end