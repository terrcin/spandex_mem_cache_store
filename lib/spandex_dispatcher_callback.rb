require 'dispatcher'

module SpandexDispatcherCallback
  
  def self.included(base)

    base.class_eval <<-EOF
      before_dispatch :clear_local_cache
  
      def clear_local_cache
        Rails.cache.clear_local
      end
    EOF

  end
  
end